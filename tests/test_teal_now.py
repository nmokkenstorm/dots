"""teal-now: the pure fold from Now Playing snapshots to teal.fm records."""

import importlib.machinery
import importlib.util
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

PATH = Path(__file__).resolve().parents[1] / "bin" / "teal-now"
loader = importlib.machinery.SourceFileLoader("teal_now", str(PATH))
spec = importlib.util.spec_from_loader("teal_now", loader)
tn = importlib.util.module_from_spec(spec)
loader.exec_module(tn)

T0 = datetime(2026, 11, 21, 12, 0, tzinfo=timezone.utc)
POLICY = tn.Policy(trusted=frozenset({"com.spotify.client"}), classified=frozenset())
MUSIC = lambda track, raw: tn.Music(None)
UNSURE = lambda track, raw: tn.Unsure("no match")
NOT_MUSIC = lambda track, raw: tn.NotMusic("talk")


def snap(title="Song", artist="Artist", duration=200, playing=True, source="com.spotify.client", key="k1", album="LP"):
    return {"title": title, "artist": artist, "duration": duration, "playing": playing, "playbackRate": 1,
            "bundleIdentifier": source, "contentItemIdentifier": key, "album": album}


def kinds(effects):
    return [effect[0] for effect in effects]


def at(seconds):
    return T0 + timedelta(seconds=seconds)


class Threshold(unittest.TestCase):
    def test_rule(self):
        cases = [(200, 100), (600, 240), (30, None), (10, None), (None, 120)]
        for duration, expected in cases:
            with self.subTest(duration=duration):
                track = tn.track_of(snap(duration=duration))
                self.assertEqual(tn.threshold(track), expected)


class Normalise(unittest.TestCase):
    def test_artist_cleanup(self):
        cases = [("ABEL - Topic", ("ABEL",)), ("Simon & Garfunkel", ("Simon & Garfunkel",)), ("", ())]
        for raw, expected in cases:
            with self.subTest(raw=raw):
                self.assertEqual(tn.artists_of(raw), expected)

    def test_untitled_snapshot_is_no_track(self):
        self.assertIsNone(tn.track_of({"title": "  "}))

    def test_merge_applies_diffs(self):
        base = tn.merge({}, {"type": "data", "diff": False, "payload": snap()})
        merged = tn.merge(base, {"type": "data", "diff": True, "payload": {"playing": False}})
        self.assertFalse(merged["playing"])
        self.assertEqual(merged["title"], "Song")
        replaced = tn.merge(merged, {"type": "data", "diff": False, "payload": {"title": "Other"}})
        self.assertEqual(replaced, {"title": "Other"})


class Fold(unittest.TestCase):
    def test_start_publishes_status(self):
        play, effects = tn.step(None, snap(), T0, POLICY, MUSIC)
        self.assertEqual(kinds(effects), ["status"])
        self.assertEqual(effects[0][1]["item"]["trackName"], "Song")
        self.assertEqual(effects[0][1]["expiry"], tn.iso(at(260)))

    def test_unlisted_source_publishes_nothing(self):
        play, effects = tn.step(None, snap(source="org.mozilla.firefox"), T0, POLICY, MUSIC)
        self.assertIsNone(play)
        self.assertEqual(effects, [])

    def test_scrobbles_once_after_threshold(self):
        play, _ = tn.step(None, snap(), T0, POLICY, MUSIC)
        play, effects = tn.tick(play, at(99))
        self.assertEqual(effects, [])
        play, effects = tn.tick(play, at(100))
        self.assertEqual(kinds(effects), ["play"])
        record = effects[0][1]
        self.assertEqual(record["$type"], "fm.teal.feed.play")
        self.assertEqual(record["playedTime"], tn.iso(T0))
        self.assertEqual(record["duration"], 200)
        self.assertEqual(record["releaseName"], "LP")
        play, effects = tn.tick(play, at(190))
        self.assertEqual(effects, [])

    def test_paused_time_does_not_count(self):
        play, _ = tn.step(None, snap(), T0, POLICY, MUSIC)
        play, effects = tn.step(play, snap(playing=False), at(60), POLICY, MUSIC)
        self.assertEqual(kinds(effects), ["clear_status"])
        play, effects = tn.tick(play, at(500))
        self.assertEqual(effects, [])
        play, effects = tn.step(play, snap(), at(500), POLICY, MUSIC)
        self.assertEqual(kinds(effects), ["status"])
        play, effects = tn.tick(play, at(539))
        self.assertEqual(effects, [])
        play, effects = tn.tick(play, at(540))
        self.assertEqual(kinds(effects), ["play"])

    def test_skip_before_threshold_never_scrobbles(self):
        play, _ = tn.step(None, snap(), T0, POLICY, MUSIC)
        play, effects = tn.step(play, snap(title="Next", key="k2"), at(20), POLICY, MUSIC)
        self.assertEqual(kinds(effects), ["status"])
        self.assertEqual(play.track.title, "Next")

    def test_switch_to_unlisted_source_clears_status(self):
        play, _ = tn.step(None, snap(), T0, POLICY, MUSIC)
        play, effects = tn.step(play, snap(source="org.mozilla.firefox", key="k9"), at(10), POLICY, MUSIC)
        self.assertIsNone(play)
        self.assertEqual(kinds(effects), ["clear_status"])

    def test_short_track_never_scrobbles(self):
        play, _ = tn.step(None, snap(duration=25), T0, POLICY, MUSIC)
        play, effects = tn.tick(play, at(600))
        self.assertEqual(effects, [])

    def test_unknown_duration_uses_four_minutes_and_omits_duration(self):
        play, effects = tn.step(None, snap(duration=None, album=""), T0, POLICY, MUSIC)
        self.assertEqual(effects[0][1]["expiry"], tn.iso(at(600)))
        play, effects = tn.tick(play, at(120))
        record = effects[0][1]
        self.assertNotIn("duration", record)
        self.assertNotIn("releaseName", record)


def recording(title, artists, length=None, score=100, release=("rel-1", "LP")):
    return {"id": "rec-1", "score": score, "title": title, "length": length,
            "artist-credit": [{"name": name, "artist": {"id": f"art-{name}"}} for name in artists],
            "releases": [{"id": release[0], "title": release[1]}]}


FIREFOX = tn.Policy(trusted=frozenset({"com.spotify.client"}), classified=frozenset({"org.mozilla.firefox"}),
                    allow=frozenset({"ABEL"}), deny=frozenset({"Some Podcast"}))


def judge_ff(title, artist, album="", duration=200, found=()):
    payload = snap(title=title, artist=artist, album=album, duration=duration, source="org.mozilla.firefox")
    track = tn.track_of(payload)
    return tn.classify(track, artist, FIREFOX, lambda a, t: list(found))


class Classify(unittest.TestCase):
    def test_verdicts(self):
        cases = [
            ("allowlisted artist", judge_ff("Anything", "ABEL - Topic"), tn.Music),
            ("denylisted artist", judge_ff("Ep 12", "Some Podcast", found=[recording("Ep 12", ["Some Podcast"])]), tn.NotMusic),
            ("too long", judge_ff("Mix", "DJ", duration=3600), tn.NotMusic),
            ("musicbrainz match", judge_ff("Hete Take", "Sef", duration=172, found=[recording("HETE TAKE", ["Abel", "Sef"], 172000)]), tn.Music),
            ("topic channel without match", judge_ff("Song", "Band - Topic"), tn.Music),
            ("album without match", judge_ff("Song", "Band", album="LP"), tn.Music),
            ("talk word without match", judge_ff("Conference keynote", "Some Channel"), tn.NotMusic),
            ("talk word with match", judge_ff("Talk", "Hozier", found=[recording("Talk", ["Hozier"])]), tn.Music),
            ("unknown video", judge_ff("Something", "Random Channel"), tn.Unsure),
        ]
        for name, verdict, expected in cases:
            with self.subTest(name):
                self.assertIsInstance(verdict, expected)

    def test_youtube_title_is_split_and_denoised(self):
        track = tn.track_of(snap(title="Abel - Hete Take (Official Video) [4K]", artist="AbelVideos", album=""))
        self.assertEqual(tn.search_terms(track, "AbelVideos"), ("Abel", "Hete Take"))

    def test_match_rejects_wrong_length_or_artist(self):
        found = [recording("Hete Take", ["Abel"], 400000)]
        self.assertIsNone(tn.best_match(found, "Abel", "Hete Take", 172))
        self.assertIsNone(tn.best_match([recording("Hete Take", ["Someone Else"])], "Abel", "Hete Take", None))
        self.assertIsNone(tn.best_match([recording("Hete Take", ["Abel"], score=50)], "Abel", "Hete Take", None))

    def test_match_carries_musicbrainz_ids_into_the_play(self):
        match = tn.best_match([recording("HETE TAKE", ["Abel", "Sef"], 172000)], "Abel", "Hete Take", 172)
        play = tn.Play(tn.track_of(snap(album="")), tn.Music(match), T0, 0.0, T0, False)
        record = tn.play_record(play)
        self.assertEqual(record["recordingMbId"], "mbid:rec-1")
        self.assertEqual(record["releaseMbId"], "mbid:rel-1")
        self.assertEqual(record["releaseName"], "LP")
        self.assertEqual([a["artistName"] for a in record["artists"]], ["Abel", "Sef"])
        self.assertEqual(record["artists"][0]["artistMbId"], "mbid:art-Abel")


class Gating(unittest.TestCase):
    def test_unsure_plays_go_to_review_and_never_publish_status(self):
        play, effects = tn.step(None, snap(), T0, POLICY, UNSURE)
        self.assertEqual(effects, [])
        play, effects = tn.tick(play, at(100))
        self.assertEqual(kinds(effects), ["review"])
        self.assertEqual(effects[0][1]["reason"], "no match")

    def test_not_music_publishes_nothing(self):
        play, effects = tn.step(None, snap(), T0, POLICY, NOT_MUSIC)
        play, later = tn.tick(play, at(500))
        self.assertEqual(effects + later, [])

    def test_judge_runs_once_per_track(self):
        calls = []
        judge = lambda track, raw: calls.append(track.key) or tn.Music(None)
        play, _ = tn.step(None, snap(), T0, POLICY, judge)
        play, _ = tn.step(play, snap(playing=False), at(5), POLICY, judge)
        play, _ = tn.step(play, snap(), at(9), POLICY, judge)
        self.assertEqual(len(calls), 1)


class Identity(unittest.TestCase):
    def test_new_content_id_for_the_same_song_keeps_the_play(self):
        play, _ = tn.step(None, snap(key="a"), T0, POLICY, MUSIC)
        play, effects = tn.step(play, snap(key="b"), at(30), POLICY, MUSIC)
        self.assertEqual(effects, [])
        self.assertEqual(play.started, T0)

    def test_musicbrainz_length_fills_a_missing_duration(self):
        match = tn.best_match([recording("Song", ["Artist"], 172000)], "Artist", "Song", None)
        judge = lambda track, raw: tn.Music(match)
        play, _ = tn.step(None, snap(duration=None), T0, POLICY, judge)
        self.assertEqual(play.track.duration, 172)
        play, _ = tn.step(play, snap(duration=None, playing=True), at(10), POLICY, judge)
        self.assertEqual(play.track.duration, 172)
        play, effects = tn.tick(play, at(86))
        self.assertEqual(kinds(effects), ["play"])
        self.assertEqual(effects[0][1]["duration"], 172)


if __name__ == "__main__":
    unittest.main()
