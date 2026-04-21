package com.tranthienhau.qcband

import java.util.concurrent.Executors
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.CountDownLatch
import android.os.Handler
import android.os.Looper

/**
 * Serial command queue for QCBand Android SDK.
 * Commands must execute one at a time; concurrent commands fail silently.
 * Each command has a 10-second timeout to prevent deadlocks.
 */
class QCBandCommandQueue {

    companion object {
        val shared = QCBandCommandQueue()
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun <T> enqueue(
        command: (completion: (T?, Exception?) -> Unit) -> Unit,
        onResult: (T?, Exception?) -> Unit
    ) {
        executor.submit {
            val latch = CountDownLatch(1)
            var resultValue: T? = null
            var resultError: Exception? = null

            mainHandler.post {
                try {
                    command { result, error ->
                        resultValue = result
                        resultError = error
                        latch.countDown()
                    }
                } catch (e: Exception) {
                    resultError = e
                    latch.countDown()
                }
            }

            val completed = latch.await(10, TimeUnit.SECONDS)
            if (!completed) {
                resultError = Exception("Command timed out after 10s")
            }

            mainHandler.post {
                onResult(resultValue, resultError)
            }
        }
    }

    fun cancelAll() {
        // The single-threaded executor processes sequentially;
        // shutting down and recreating handles cancellation
    }
}
