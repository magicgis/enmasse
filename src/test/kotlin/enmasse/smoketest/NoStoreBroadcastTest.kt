package enmasse.smoketest

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * @author Ulf Lilleengen
 */
class NoStoreBroadcastTest {
    @Test
    fun testMultipleRecievers() {
        val dest = "broadcast"
        val client = EnMasseClient(createQueueContext(dest), 3, true)
        val msgs = listOf("foo", "bar", "baz")

        val executor = Executors.newFixedThreadPool(3)
        val recvResults = 1.rangeTo(2).map { i -> executor.submit<List<String>> { client.recvMessages(dest, msgs.size) } }
        val sendResult = executor.submit<Int> { client.sendMessages(dest, msgs) }

        executor.shutdown()
        assertTrue("Clients did not terminate within timeout", executor.awaitTermination(30, TimeUnit.SECONDS))

        assertEquals(msgs.size, sendResult.get())
        recvResults.forEach { result -> assertEquals(msgs.size, result.get().size) }
    }
}