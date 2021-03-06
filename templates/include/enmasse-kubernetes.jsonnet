local templateConfig = import "template-config.jsonnet";
local addressController = import "address-controller.jsonnet";
local common = import "common.jsonnet";
local restapiRoute = import "restapi-route.jsonnet";
local messagingService = import "messaging-service.jsonnet";
local mqttService = import "mqtt-service.jsonnet";
local consoleService = import "console-service.jsonnet";
local images = import "images.jsonnet";
{
  common(with_kafka)::
  {
    "apiVersion": "v1",
    "kind": "List",
    "items": [ templateConfig.generate(with_kafka),
               addressController.deployment(images.address_controller, "enmasse-template-config", "enmasse-ca", "address-controller-cert", "development", "false"),
               addressController.internal_service ]
  },

  external_lb::
    addressController.external_service,
}
