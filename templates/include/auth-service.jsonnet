local common = import "common.jsonnet";
local images = import "images.jsonnet";
{
  envVars::
    [
      common.env("AUTHENTICATION_SERVICE_HOST", "${AUTHENTICATION_SERVICE_HOST}"),
      common.env("AUTHENTICATION_SERVICE_PORT", "${AUTHENTICATION_SERVICE_PORT}"),
      common.env("AUTHENTICATION_SERVICE_CLIENT_SECRET", "${AUTHENTICATION_SERVICE_CLIENT_SECRET}"),
      common.env("AUTHENTICATION_SERVICE_SASL_INIT_HOST", "${AUTHENTICATION_SERVICE_SASL_INIT_HOST}")
    ],

  none_authservice::
  {
    "apiVersion": "v1",
    "kind": "Service",
    "metadata": {
      "name": "none-authservice",
      "labels": {
        "app": "enmasse"
      }
    },
    "spec": {
      "ports": [
        {
          "name": "amqps",
          "port": 5671,
          "protocol": "TCP",
          "targetPort": "amqps"
        }
      ],
      "selector": {
        "name": "none-authservice"
      }
    }
  },


  standard_authservice::
  {
    "apiVersion": "v1",
    "kind": "Service",
    "metadata": {
      "name": "standard-authservice",
      "labels": {
        "app": "enmasse"
      }
    },
    "spec": {
      "ports": [
        {
          "name": "amqps",
          "port": 5671,
          "protocol": "TCP",
          "targetPort": "amqps"
        },
        {
          "name": "https",
          "port": 8443,
          "protocol": "TCP",
          "targetPort": "https"
        }
      ],
      "selector": {
        "name": "keycloak"
      }
    }
  },

  keycloak_controller_deployment(keycloak_controller_image, keycloak_credentials_secret, cert_secret)::
    {
      "apiVersion": "extensions/v1beta1",
      "kind": "Deployment",
      "metadata": {
        "labels": {
          "app": "enmasse"
        },
        "name": "keycloak-controller"
      },
      "spec": {
        "replicas": 1,
        "template": {
          "metadata": {
            "labels": {
              "name": "keycloak-controller",
              "app": "enmasse"
            }
          },
          "spec": {
            "containers": [
              {
                "image": keycloak_controller_image,
                "name": "keycloak-controller",
                "resources": {
                    "requests": {
                        "memory": "256Mi",
                    },
                    "limits": {
                        "memory": "256Mi",
                    }
                },
                "env": [
                  {
                    "name": "STANDARD_AUTHSERVICE_ADMIN_USER",
                    "valueFrom": {
                      "secretKeyRef": {
                        "name": keycloak_credentials_secret,
                        "key": "admin.username"
                      }
                    }
                  },
                  {
                    "name": "STANDARD_AUTHSERVICE_ADMIN_PASSWORD",
                    "valueFrom": {
                      "secretKeyRef": {
                        "name": keycloak_credentials_secret,
                        "key": "admin.password"
                      }
                    }
                  },
                  {
                    "name": "STANDARD_AUTHSERVICE_CA_CERT",
                    "valueFrom": {
                      "secretKeyRef": {
                        "name": cert_secret,
                        "key": "tls.crt"
                      }
                    }
                  }
                ]
              }
            ],
          }
        }
      }
    },


  keycloak_deployment(keycloak_image, keycloak_credentials_secret, cert_secret_name, pvc_claim_name)::
    {
      "apiVersion": "extensions/v1beta1",
      "kind": "Deployment",
      "metadata": {
        "labels": {
          "app": "enmasse"
        },
        "name": "keycloak"
      },
      "spec": {
        "replicas": 1,
        "template": {
          "metadata": {
            "labels": {
              "name": "keycloak",
              "app": "enmasse"
            }
          },
          "spec": {
            "containers": [
              {
                "image": keycloak_image,
                "name": "keycloak",
                "ports": [
                  common.container_port("amqps", 5671),
                  common.container_port("https", 8443)
                ],
                "env": [
                  {
                    "name": "KEYCLOAK_USER",
                    "valueFrom": {
                      "secretKeyRef": {
                        "name": keycloak_credentials_secret,
                        "key": "admin.username"
                      }
                    }
                  },
                  {
                    "name": "KEYCLOAK_PASSWORD",
                    "valueFrom": {
                      "secretKeyRef": {
                        "name": keycloak_credentials_secret,
                        "key": "admin.password"
                      }
                    }
                  }
                ],
                "volumeMounts": [
                  common.volume_mount("keycloak-persistence", "/opt/jboss/keycloak/standalone/data"),
                  common.volume_mount(cert_secret_name, "/opt/jboss/keycloak/standalone/cert")
                ],
                "livenessProbe": common.http_probe("https", "/", "HTTPS", 120)
              }
            ],
            "volumes": [
              common.secret_volume(cert_secret_name, cert_secret_name),
              common.persistent_volume("keycloak-persistence", pvc_claim_name)
            ]
          }
        }
      }
    },

  keycloak_pvc(name, capacity)::
  {
    "apiVersion": "v1",
    "kind": "PersistentVolumeClaim",
    "metadata": {
      "name": name,
      "labels": {
        "app": "enmasse"
      }
    },
    "spec": {
      "accessModes": [
        "ReadWriteOnce"
      ],
      "resources": {
        "requests": {
          "storage": capacity
        }
      }
    }
  },

  keycloak_route(hostname)::
    {
      "kind": "Route",
      "apiVersion": "v1",
      "metadata": {
          "labels": {
            "app": "enmasse"
          },
          "name": "keycloak"
      },
      "spec": {
        "host": hostname,
        "to": {
            "kind": "Service",
            "name": "standard-authservice"
        },
        "port": {
            "targetPort": "https"
        },
        "tls": {
          "termination": "passthrough"
        }
      }
    },


  none_deployment(none_authservice_image, cert_secret_name)::
    {
      "apiVersion": "extensions/v1beta1",
      "kind": "Deployment",
      "metadata": {
        "labels": {
          "app": "enmasse"
        },
        "name": "none-authservice"
      },
      "spec": {
        "replicas": 1,
        "template": {
          "metadata": {
            "labels": {
              "name": "none-authservice",
              "app": "enmasse"
            }
          },
          "spec": {
            "containers": [
              {
                "image": none_authservice_image,
                "name": "none-authservice",
                "env": [
                  common.env("LISTENPORT", "5671")
                ],
                "resources": {
                    "requests": {
                        "memory": "48Mi",
                    },
                    "limits": {
                        "memory": "48Mi",
                    }
                },
                "ports": [
                  common.container_port("amqps", 5671)
                ],
                "livenessProbe": common.tcp_probe("amqps", 60),
                "volumeMounts": [
                  common.volume_mount(cert_secret_name, "/opt/none-authservice/cert")
                ]
              },
            ],
            "volumes": [
              common.secret_volume(cert_secret_name, cert_secret_name)
            ]
          }
        }
      }
    },

  local me = self,
  keycloak_kubernetes::
  {
    "apiVersion": "v1",
    "kind": "List",
    "items": [
      me.keycloak_pvc("keycloak-pvc", "2Gi"),
      me.keycloak_deployment(images.keycloak, "keycloak-credentials", "standard-authservice-cert", "keycloak-pvc"),
      me.keycloak_controller_deployment(images.keycloak_controller, "keycloak-credentials", "standard-authservice-cert"),
      me.standard_authservice
    ],
  },

  keycloak_openshift::
  {
    "apiVersion": "v1",
    "kind": "Template",
    "objects": [
      me.keycloak_pvc("keycloak-pvc", "${KEYCLOAK_STORAGE_CAPACITY}"),
      me.keycloak_deployment("${STANDARD_AUTHSERVICE_IMAGE}", "${KEYCLOAK_SECRET_NAME}", "${STANDARD_AUTHSERVICE_SECRET_NAME}", "keycloak-pvc"),
      me.keycloak_controller_deployment("${KEYCLOAK_CONTROLLER_IMAGE}", "${KEYCLOAK_SECRET_NAME}", "${STANDARD_AUTHSERVICE_SECRET_NAME}"),
      me.standard_authservice,
      me.keycloak_route("${KEYCLOAK_ROUTE_HOSTNAME}")
    ],
    "parameters": [
      {
        "name": "STANDARD_AUTHSERVICE_IMAGE",
        "description": "The docker image to use for the 'standard' auth service",
        "value": images.keycloak
      },
      {
        "name": "KEYCLOAK_SECRET_NAME",
        "description": "The secret where keycloak credentials are stored",
        "value": "keycloak-credentials"
      },
      {
        "name": "KEYCLOAK_CONTROLLER_IMAGE",
        "description": "The docker image to use for the keycloak controller",
        "value": images.keycloak_controller
      },
      {
        "name": "STANDARD_AUTHSERVICE_SECRET_NAME",
        "description": "The secret containing the tls certificate and key",
        "value": "standard-authservice-cert"
      },
      {
        "name": "KEYCLOAK_ROUTE_HOSTNAME",
        "description": "The hostname to use for the public keycloak route",
        "value": ""
      },
      {
        "name": "KEYCLOAK_STORAGE_CAPACITY",
        "description": "The amount of storage to request for Keycloak data",
        "value": "2Gi"
      }
    ]
  },

  none_kubernetes::
  {
    "apiVersion": "v1",
    "kind": "List",
    "items": [
      me.none_deployment(images.none_authservice, "none-authservice-cert"),
      me.none_authservice,
    ],
  },

  none_openshift::
  {
    "apiVersion": "v1",
    "kind": "Template",
    "objects": [
      me.none_deployment("${NONE_AUTHSERVICE_IMAGE}", "${NONE_AUTHSERVICE_CERT_SECRET_NAME}"),
      me.none_authservice,
    ],
    "parameters": [
      {
        "name": "NONE_AUTHSERVICE_IMAGE",
        "description": "The docker image to use for the 'none' auth service",
        "value": images.none_authservice
      },
      {
        "name": "NONE_AUTHSERVICE_CERT_SECRET_NAME",
        "description": "The secret to use for the none-authservice certificate",
        "value": "none-authservice-cert"
      },
    ]
  },
}
