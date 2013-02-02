#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Domgen

  class CharacteristicType < BaseElement
    attr_reader :name

    def initialize(name, options, &block)
      @name = name
      Domgen::TypeDB.send :register_characteristic_type, name, self
      super(options, &block)
    end

    def to_s
      "CharacteristicType[#{self.name}]"
    end

    protected

    def root
      self
    end
  end

  class TypeDB
    class << self
      def mark_as_initialized
        characteristic_types.each do |characteristic_type|
          characteristic_type.freeze
        end
      end

      def characteristic_types
        characteristic_type_map.values
      end

      def characteristic_type(name, options = {}, &block)
        Domgen::CharacteristicType.new(name, options, &block)
      end

      def enhance(name, options = {}, &block)
        characteristic_type = characteristic_type_by_name(name)
        characteristic_type.options = options
        characteristic_type.instance_eval(&block) if block_given?
        characteristic_type
      end

      def config_elements_map
        unless @config_elements
          @config_elements = Domgen::OrderedHash.new
          @config_elements[''] = Domgen::CharacteristicType
        end
        @config_elements
      end

      def config_element?(namespace)
        !!config_elements_map[namespace.to_s]
      end

      def config_element(namespace, &block)
        unless config_element?(namespace)
          config_elements_map[namespace.to_s] =
              ::Struct.new(Domgen::Naming.pascal_case(namespace.to_s.gsub('.', '_')), :root) do
                def options=(options)
                  options.each_pair do |k, v|
                    keys = k.to_s.split('.')
                    target = self
                    keys[0, keys.length - 1].each do |target_accessor_key|
                      target = target.send target_accessor_key.to_sym
                    end
                    target.send("#{keys.last}=", v)
                  end
                end
              end

          namespace_elements = namespace.to_s.split('.')
          if namespace_elements.size > 1
            parent_namespace = namespace_elements[0, namespace_elements.length - 1].join('.')
            parent = config_element(parent_namespace)
          else
            parent = Domgen::CharacteristicType
          end
          key = namespace_elements.last
          code = <<-CODE
            def #{key}
              @#{key} ||= Domgen::TypeDB.config_element(:"#{namespace}").new(root)
            end
          CODE
          parent.class_eval(code)
        end
        config_element = config_elements_map[namespace.to_s]
        config_element.class_eval(&block) if block_given?
        config_element
      end

      def characteristic_type?(name)
        !!characteristic_type_map[name.to_s]
      end

      def characteristic_type_by_name(name)
        characteristic_type = characteristic_type_map[name.to_s]
        Domgen.error("Unable to locate characteristic_type #{name}") unless characteristic_type
        characteristic_type
      end

      private

      def register_characteristic_type(name, characteristic_type)
        Domgen.error("Attempt override characteristic_type #{name}") if characteristic_type?(name)
        characteristic_type_map[name.to_s] = characteristic_type
      end

      def characteristic_type_map
        @characteristic_types ||= Domgen::OrderedHash.new
      end
    end
  end
end

# Define the "standard set" of characteristic types
Domgen::TypeDB.characteristic_type(:void)
Domgen::TypeDB.characteristic_type(:text)
Domgen::TypeDB.characteristic_type(:integer)
Domgen::TypeDB.characteristic_type(:real)
Domgen::TypeDB.characteristic_type(:date)
Domgen::TypeDB.characteristic_type(:datetime)
Domgen::TypeDB.characteristic_type(:boolean)
Domgen::TypeDB.characteristic_type(:enumeration)
Domgen::TypeDB.characteristic_type(:struct)
Domgen::TypeDB.characteristic_type(:reference)
