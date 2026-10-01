# Thứ tự = chiều phụ thuộc của Clean Architecture (tầng trong không biết tầng ngoài):
#   domain  <-  application  <-  infrastructure / presentation  <-  app (composition root)
add_subdirectory(domain)
add_subdirectory(application)
add_subdirectory(infrastructure)
add_subdirectory(presentation)
add_subdirectory(app)
