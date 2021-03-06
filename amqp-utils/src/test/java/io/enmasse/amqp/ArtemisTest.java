/*
 * Copyright 2016 Red Hat Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package io.enmasse.amqp;

import io.vertx.core.Future;
import io.vertx.core.Vertx;
import io.vertx.ext.unit.Async;
import io.vertx.ext.unit.TestContext;
import io.vertx.ext.unit.junit.VertxUnitRunner;
import io.vertx.proton.ProtonClientOptions;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.Ignore;
import org.junit.runner.RunWith;

import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeoutException;

@RunWith(VertxUnitRunner.class)
public class ArtemisTest {

    private Vertx vertx;
    private TestArtemis server;

    @Before
    public void setup() throws Exception {
        vertx = Vertx.vertx();
        server = new TestArtemis("localhost", 12346);
        server.start();
    }

    @After
    public void teardown() {
        vertx.close();
    }


    @Test
    public void testManagement(TestContext testContext) throws InterruptedException, ExecutionException, TimeoutException {
        Future<Artemis> promise = Artemis.create(vertx, new ProtonClientOptions(), "localhost", 12346);
        Async async = testContext.async();
        promise.setHandler(result -> {
            testContext.assertTrue(result.succeeded());
            Artemis artemis = result.result();

            vertx.executeBlocking(p -> {
                try {
                    artemis.deployQueue("queue1", "queue1");
                    artemis.deployQueue("queue2", "queue2");

                    long numQueues = artemis.getNumQueues();
                    long endTime = System.currentTimeMillis() + 60_000;
                    while (numQueues != 2L && System.currentTimeMillis() < endTime) {
                        Thread.sleep(2000);
                        numQueues = artemis.getNumQueues();
                    }
                    testContext.assertEquals(2L, numQueues);
                    testContext.assertEquals(0L, artemis.getQueueMessageCount("queue1"));
                    p.complete();
                } catch (Exception e) {
                    p.fail(e);
                }
            }, r -> {
                testContext.assertTrue(r.succeeded());
                async.complete();
            });
        });
    }
}
