package com.dev.vokey

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder

class AlertLogicTest {
    // --- Volume ramp -------------------------------------------------------

    @Test
    fun rampRisesLinearlyFromStartToCap() {
        // Cap 80 %, start at 25 % of the cap, 10 s ramp.
        assertEquals(.20f, VolumeRamp.gainAt(0, 25, 80, 10_000), 1e-4f)
        assertEquals(.50f, VolumeRamp.gainAt(5_000, 25, 80, 10_000), 1e-4f)
        assertEquals(.80f, VolumeRamp.gainAt(10_000, 25, 80, 10_000), 1e-4f)
    }

    @Test
    fun rampNeverExceedsTheUserCap() {
        for (t in listOf(0L, 9_999L, 10_000L, 60_000L, Long.MAX_VALUE / 2)) {
            assertTrue(VolumeRamp.gainAt(t, 10, 60, 10_000) <= .6f + 1e-6f)
        }
        assertEquals(1f, VolumeRamp.gainAt(1_000_000, 0, 250, 1_000), 1e-6f)
    }

    @Test
    fun zeroRampMeansFullCapImmediately() {
        assertEquals(.7f, VolumeRamp.gainAt(0, 10, 70, 0), 1e-6f)
        assertEquals(.2f, VolumeRamp.gainAt(-50, 25, 80, 10_000), 1e-4f)
    }

    // --- Output routing ----------------------------------------------------

    @Test
    fun headphonesOnlyStaysSilentWithoutHeadphones() {
        assertEquals(OutputDecision.SKIP_SOUND, OutputRouting.decide(OutputPolicy.HEADPHONES, false))
        assertEquals(OutputDecision.PLAY_ON_HEADPHONES, OutputRouting.decide(OutputPolicy.HEADPHONES, true))
    }

    @Test
    fun speakerAndAutoAlwaysPlay() {
        for (connected in listOf(true, false)) {
            assertEquals(OutputDecision.PLAY_ON_SPEAKER, OutputRouting.decide(OutputPolicy.SPEAKER, connected))
            assertEquals(OutputDecision.PLAY_DEFAULT, OutputRouting.decide(OutputPolicy.AUTO, connected))
        }
    }

    @Test
    fun unknownPolicyIdFallsBackToAuto() {
        assertEquals(OutputPolicy.AUTO, OutputPolicy.fromId(null))
        assertEquals(OutputPolicy.AUTO, OutputPolicy.fromId("ask_each_time"))
        assertEquals(OutputPolicy.SPEAKER, OutputPolicy.fromId("speaker"))
    }

    // --- Custom sound files --------------------------------------------------

    @Test
    fun onlySafePrivateFileNamesAreAccepted() {
        assertTrue(CustomSoundFiles.isSafeFileName("3f2a9c_x-1.mp3"))
        assertFalse(CustomSoundFiles.isSafeFileName("../shared_prefs/x.mp3"))
        assertFalse(CustomSoundFiles.isSafeFileName("a/b.mp3"))
        assertFalse(CustomSoundFiles.isSafeFileName("sound.exe"))
        assertFalse(CustomSoundFiles.isSafeFileName(".mp3"))
        assertFalse(CustomSoundFiles.isSafeFileName(null))
    }

    @Test
    fun extensionComesFromMimeThenName() {
        assertEquals("mp3", CustomSoundFiles.extensionFor("audio/mpeg", "x.bin"))
        assertEquals("m4a", CustomSoundFiles.extensionFor("audio/mp4", null))
        assertEquals("ogg", CustomSoundFiles.extensionFor(null, "Ring.OGG"))
        assertNull(CustomSoundFiles.extensionFor("audio/x-unknown", "song.mid"))
    }

    @Test
    fun validationEnforcesSizeAndDuration() {
        assertNull(CustomSoundFiles.validate(500_000, 3_000))
        assertNotNull(CustomSoundFiles.validate(0, 3_000))
        assertNotNull(CustomSoundFiles.validate(CustomSoundFiles.MAX_BYTES + 1, 3_000))
        assertNotNull(CustomSoundFiles.validate(500_000, 0)) // undecodable
        assertNotNull(CustomSoundFiles.validate(500_000, CustomSoundFiles.MAX_DURATION_MS + 1))
    }

    @Test
    fun displayNameIsCleanedAndBounded() {
        assertEquals("My Ringtone", CustomSoundFiles.displayName("My Ringtone.mp3"))
        assertEquals("Custom sound", CustomSoundFiles.displayName(null))
        assertEquals(40, CustomSoundFiles.displayName("x".repeat(80) + ".mp3").length)
    }

    // --- Tone synthesis ----------------------------------------------------

    @Test
    fun builtInTonesAreValidPcmWav() {
        for (id in ToneSynth.builtInIds) {
            val bytes = ToneSynth.wavBytes(id)
            assertArrayEquals("RIFF".toByteArray(), bytes.copyOfRange(0, 4))
            assertArrayEquals("WAVE".toByteArray(), bytes.copyOfRange(8, 12))
            val h = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
            assertEquals(1, h.getShort(20).toInt()) // PCM
            assertEquals(1, h.getShort(22).toInt()) // mono
            assertEquals(ToneSynth.SAMPLE_RATE, h.getInt(24))
            assertEquals(bytes.size - 44, h.getInt(40))
            // ~1.2–1.4 s per cycle so looping keeps a pulse rhythm.
            val seconds = (bytes.size - 44) / 2.0 / ToneSynth.SAMPLE_RATE
            assertTrue("$id length $seconds", seconds in 1.1..1.5)
        }
    }

    @Test
    fun tonesStartAndEndSilentToAvoidClicks() {
        val pcm = ToneSynth.pcm("classic_beep")
        assertEquals(0, pcm.first().toInt())
        assertEquals(0, pcm.last().toInt())
        assertTrue(pcm.any { kotlin.math.abs(it.toInt()) > 20_000 })
    }
}
