# Order = dependency direction of the Clean Architecture (inner layers know nothing about outer ones):
#   domain  <-  application  <-  infrastructure / presentation  <-  app (composition root)
add_subdirectory(domain)
add_subdirectory(application)
add_subdirectory(infrastructure)
add_subdirectory(presentation)
add_subdirectory(app)
