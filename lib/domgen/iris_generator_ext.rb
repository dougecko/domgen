module Domgen
  module Generator
    def self.define_iris_templates
      [
          Template.new(:object_type,
                       'iris/model',
                       'java/#{object_type.java.fully_qualified_name.gsub(".","/")}Bean.java',
                       [],
                       'object_type.iris.generate?'),
          Template.new(:object_type,
                       'iris/persist_peer',
                       'java/#{object_type.schema.java.package.gsub(".","/")}/persist/#{object_type.java.classname}PersistPeer.java',
                       [],
                       'object_type.iris.generate? && object_type.name != :Batch'),
          Template.new(:schema,
                       'iris/xml_generator',
                       'java/#{schema.java.package.gsub(".","/")}/#{schema.name}XMLGenerator.java',
                       [],
                       'schema.iris.generate?'),
          Template.new(:schema,
                       'iris/sync',
                       'java/#{schema.java.package.gsub(".","/")}/#{schema.name}Sync.java',
                       [],
                       'schema.iris.generate?'),
          Template.new(:schema,
                       'iris/codec',
                       'java/#{schema.java.package.gsub(".","/")}/#{schema.name}Codec.java',
                       [],
                       'schema.iris.generate?'),
          Template.new(:schema,
                       'iris/module',
                       'java/#{schema.java.package.gsub(".","/")}/#{schema.name}Module.java',
                       [],
                       'schema.iris.generate?'),
          Template.new(:schema,
                       'iris/validator',
                       'java/#{schema.java.package.gsub(".","/")}/#{schema.name}Validator.java',
                       [],
                       'schema.iris.generate?'),
          Template.new(:schema,
                       'iris/visitor',
                       'java/#{schema.java.package.gsub(".","/")}/visitor/Visitor.java',
                       [],
                       'schema.iris.generate?'),
          Template.new(:schema,
                       'iris/abstract_visitor',
                       'java/#{schema.java.package.gsub(".","/")}/visitor/AbstractVisitor.java',
                       [],
                       'schema.iris.generate?'),
          Template.new(:schema,
                       'iris/filter',
                       'java/#{schema.java.package.gsub(".","/")}/visitor/Filter.java',
                       [],
                       'schema.iris.generate?'),
          Template.new(:schema,
                       'iris/abstract_filter',
                       'java/#{schema.java.package.gsub(".","/")}/visitor/AbstractFilter.java',
                       [],
                       'schema.iris.generate?'),
          Template.new(:schema,
                       'iris/chain_filter',
                       'java/#{schema.java.package.gsub(".","/")}/visitor/ChainFilter.java',
                       [],
                       'schema.iris.generate?'),
          Template.new(:schema,
                       'iris/traverser',
                       'java/#{schema.java.package.gsub(".","/")}/visitor/Traverser.java',
                       [],
                       'schema.iris.generate?'),
      ]
    end
  end
end