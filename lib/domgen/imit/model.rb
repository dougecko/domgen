module Domgen
  module Imit

    class ImitationAttribute < Domgen.ParentedElement(:attribute)

      def field_name
        attribute.name
      end

      attr_writer :client_side

      def client_side?
        @client_side.nil? ? true : @client_side
      end

      include Domgen::Java::JavaCharacteristic

      protected

      def characteristic
        attribute
      end

      def entity_to_classname(entity)
        entity.imit.qualified_imitation_name
      end

      def enumeration_to_classname(enumeration)
        enumeration.imit.qualified_enumeration_name
      end
    end

    class ImitationClass < Domgen.ParentedElement(:entity)

      def imitation_name
        entity.name
      end

      def qualified_imitation_name
        "#{entity.data_module.imit.imitation_package}.#{imitation_name}"
      end

      attr_writer :client_side

      def client_side?
        @client_side.nil? ? true : @client_side
      end
    end

    class ImitationEnumeration < Domgen.ParentedElement(:enumeration)
      def enumeration_name
        "#{enumeration.name}"
      end

      def qualified_enumeration_name
        "#{enumeration.data_module.imit.imitation_package}.#{enumeration.name}"
      end
    end

    class ImitationModule < Domgen.ParentedElement(:data_module)
      attr_writer :imitation_package

      def imitation_package
        @imitation_package || "#{Domgen::Naming.underscore(data_module.repository.name)}.#{Domgen::Naming.underscore(data_module.name)}"
      end

      def json_mapper_name
        "#{data_module.name}JSONMapper"
      end

      def qualified_json_mapper_name
        "#{imitation_package}.#{json_mapper_name}"
      end

      def updater_name
        "#{data_module.name}Updater"
      end

      def qualified_updater_name
        "#{imitation_package}.#{updater_name}"
      end
    end
  end

  FacetManager.define_facet(:imit,
                            EnumerationSet => Domgen::Imit::ImitationEnumeration,
                            Attribute => Domgen::Imit::ImitationAttribute,
                            Entity => Domgen::Imit::ImitationClass,
                            DataModule => Domgen::Imit::ImitationModule)
end
