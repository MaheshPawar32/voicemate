package com.dev.vokey

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class OfflineCommandEngineTest {
    @Test
    fun findPhonePhrasesMapToFinderIntent() {
        assertEquals("find_phone", OfflineCommandEngine.intentForTranscript("find my phone"))
        assertEquals("find_phone", OfflineCommandEngine.intentForTranscript("Where are you?"))
        assertEquals("find_phone", OfflineCommandEngine.intentForTranscript("HELLO VOICE MATE"))
    }

    @Test
    fun lockPhrasesMapOnlyToLockIntent() {
        assertEquals("lock_phone", OfflineCommandEngine.intentForTranscript("lock my phone"))
        assertEquals("lock_phone", OfflineCommandEngine.intentForTranscript("lock this phone"))
    }

    @Test
    fun stopPhrasesMapToStopMonitoring() {
        assertEquals("stop_monitoring", OfflineCommandEngine.intentForTranscript("stop listening"))
        assertEquals("stop_monitoring", OfflineCommandEngine.intentForTranscript("stop monitoring"))
    }

    @Test
    fun unsupportedPhrasesAreIgnored() {
        assertNull(OfflineCommandEngine.intentForTranscript(""))
        assertNull(OfflineCommandEngine.intentForTranscript("unlock my phone"))
        assertNull(OfflineCommandEngine.intentForTranscript("open my messages"))
    }
}
