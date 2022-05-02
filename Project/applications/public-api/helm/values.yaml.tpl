image:
  repository: ${artifact.image}
  tag: ${artifact.tag}
  pullPolicy: Always
  pullSecrets: null

namespace: ${var.k8s_namespace}

env:
- name: BIND_ADDRESS
  value: ":8080"
- name: PRODUCT_API_URI
  value: "http://product-api:9090"
- name: PAYMENT_API_URI
  value: "http://payments:8080"
%{ for k,v in entrypoint.env }  
- name: ${k}
  value: "${v}"
%{ endfor }

resources: {}
  # We usually recommend not to specify default resources and to leave this as a conscious
  # choice for the user. This also increases chances charts run on environments with little
  # resources, such as Minikube. If you do want to specify resources, uncomment the following
  # lines, adjust them as necessary, and remove the curly braces after 'resources:'.
  # limits:
  #   cpu: 100m
  #   memory: 128Mi
  # requests:
  #   cpu: 100m
  #   memory: 128Mi
