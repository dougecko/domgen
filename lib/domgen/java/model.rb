module Domgen
  module Java
    TYPE_MAP = {"integer" => "java.lang.Integer",
                "boolean" => "java.lang.Boolean",
                "datetime" => "java.util.Date",
                "text" => "java.lang.String",
                "void" => "java.lang.Void" }

    module JavaCharacteristic
      def name(modality = :default)
        if :default == modality
          return characteristic.name
        elsif :boundary == modality
          return characteristic.referencing_link_name if characteristic.reference?
          return characteristic.name
        else
          error("unknown modality #{modality}")
        end
      end

      attr_writer :java_type

      def java_type(modality = :default)
        return @java_type if @java_type
        return "void" if :void == characteristic.characteristic_type
        return primitive_java_type(modality) if primitive?(modality)
        non_primitive_java_type(modality)
      end

      def java_component_type(modality = :default)
        if characteristic.characteristic_type == :struct && :none != characteristic.collection_type
          return characteristic.struct.send(struct_key).qualified_name
        else
          java_type(modality)
        end
      end

      def non_primitive_java_type(modality = :default)
        if characteristic.reference?
          if :default == modality
            return characteristic.referenced_entity.send(facet_key).qualified_name
          elsif :boundary == modality
            return characteristic.referenced_entity.primary_key.send(facet_key).non_primitive_java_type(modality)
          else
            error("unknown modality #{modality}")
          end
        elsif characteristic.enumeration?
          if :default == modality
            return characteristic.enumeration.send(facet_key).qualified_name
          elsif :boundary == modality
            if characteristic.enumeration.textual_values?
              return "java.lang.String"
            else
              return "java.lang.Integer"
            end
          else
            error("unknown modality #{modality}")
          end
        elsif characteristic.characteristic_type == :struct
          if :none == characteristic.collection_type
            return characteristic.struct.send(struct_key).qualified_name
          elsif :sequence == characteristic.collection_type
            return "java.util.List<#{characteristic.struct.send(struct_key).qualified_name}>"
          else
            error("unknown collection_type #{characteristic.collection_type}")
          end
        elsif characteristic.characteristic_type == :date
          return date_java_type
        else
          return Domgen::Java::TYPE_MAP[characteristic.characteristic_type.to_s] || characteristic.characteristic_type.to_s
        end
      end

      def primitive?(modality = :default)
        return false if characteristic.nullable?
        return false if (characteristic.respond_to?(:generated_value?) && characteristic.generated_value?)
        return true if characteristic.integer? || characteristic.boolean?
        return true if :boundary == modality && characteristic.enumeration? && characteristic.enumeration.numeric_values?

        if :default == modality
          return false
        elsif :boundary == modality
          return false unless characteristic.reference?
          return characteristic.referenced_entity.primary_key.integer? || characteristic.referenced_entity.primary_key.boolean?
        else
          error("unknown modality #{modality}")
        end
      end

      def primitive_java_type(modality = :default)
        return "int" if characteristic.integer?
        return "boolean" if characteristic.boolean?
        if :boundary == modality
          if characteristic.reference?
            return characteristic.referenced_entity.primary_key.send(facet_key).primitive_java_type
          elsif characteristic.enumeration? && characteristic.enumeration.numeric_values?
            return "int"
          end
        end
        error("primitive_java_type invoked for non primitive method")
      end

      def characteristic_type(modality = :default)
        if :default == modality
          return characteristic.characteristic_type
        elsif :boundary == modality
          return characteristic.reference? ? characteristic.referenced_entity.primary_key.send(facet_key).characteristic_type : characteristic.characteristic_type
        else
          error("unknown modality #{modality}")
        end
      end

      protected

      def characteristic
        raise "characteristic unimplemented"
      end

      def facet_key
        raise "facet_key unimplemented"
      end

      def struct_key
        raise "struct_key unimplemented"
      end
    end

    module EEJavaCharacteristic
      include JavaCharacteristic

      protected

      def facet_key
        :jpa
      end

      def struct_key
        :jaxb
      end

      def date_java_type
        "java.util.Date"
      end
    end

    module ImitJavaCharacteristic
      include JavaCharacteristic

      protected

      def facet_key
        :imit
      end

      def struct_key
        :jaxb
      end

      def date_java_type
        "org.realityforge.replicant.client.RDate"
      end
    end
  end
end
