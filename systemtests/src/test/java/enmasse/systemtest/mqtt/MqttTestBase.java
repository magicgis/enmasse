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

package enmasse.systemtest.mqtt;

import enmasse.systemtest.Endpoint;
import enmasse.systemtest.TestBase;
import org.junit.After;
import org.junit.Before;

import java.util.ArrayList;
import java.util.List;

/**
 * Base class for all MQTT related tests
 */
public abstract class MqttTestBase extends TestBase {

    private final List<MqttClient> clients = new ArrayList<>();

    @Before
    public void setupMqttTest() throws Exception {
        this.clients.clear();
    }

    @After
    public void teardownMqttTest() throws Exception {

        for (MqttClient client : this.clients) {
            client.close();
        }
        this.clients.clear();
    }

    protected MqttClient createClient() {

        Endpoint mqttEndpoint = this.openShift.getEndpoint("mqtt", "mqtt");

        MqttClient client = new MqttClient(mqttEndpoint);
        this.clients.add(client);
        return client;
    }
}