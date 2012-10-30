module Domgen
  module Generator
    module JWS
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:jws]
      HELPERS = [Domgen::Java::Helper]
    end
  end
end
Domgen.template_set(:jws) do |template_set|
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :service,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/boundary_implementation.java.erb",
                        'main/java/#{service.jws.qualified_boundary_implementation_name.gsub(".","/")}.java',
                        Domgen::Generator::JWS::HELPERS)
end