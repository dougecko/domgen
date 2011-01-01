module Domgen
  module Sql
    class SqlElement < BaseConfigElement
      attr_reader :parent

      def initialize(parent, options = {}, &block)
        @parent = parent
        super(options, &block)
      end
    end

    class SqlSchema < SqlElement
      DEFAULT_SCHEMA = 'dbo'

      attr_writer :schema

      def schema
        @schema = parent.name unless @schema
        @schema
      end

      def default_schema?
        DEFAULT_SCHEMA == schema
      end
    end

    class Index < BaseConfigElement
      attr_reader :table
      attr_accessor :attribute_names
      attr_accessor :include_attribute_names
      attr_accessor :filter

      def initialize(table, attribute_names, options, &block)
        @table = table
        @attribute_names = attribute_names
        @include_attribute_names = []
        super(options, &block)
      end

      attr_writer :name

      def name
        if @name.nil?
          prefix = cluster? ? 'CL' : unique? ? 'UQ' : 'IX'
          suffix = attribute_names.join('_')
          @name = "#{prefix}_#{table.parent.name}_#{suffix}"
        end
        @name
      end

      attr_writer :cluster

      def cluster?
        @cluster = false if @cluster.nil?
        @cluster
      end

      attr_writer :unique

      def unique?
        @unique = false if @unique.nil?
        @unique
      end
    end

    class ForeignKey < BaseConfigElement
      ACTION_MAP =
        {
          :cascade => "CASCADE",
          :restrict => "RESTRICT",
          :set_null => "SET NULL",
          :set_default => "SET DEFAULT",
          :no_action => "NO ACTION"
        }.freeze

      attr_reader :table
      attr_accessor :attribute_names
      attr_accessor :referenced_object_type_name
      attr_accessor :referenced_attribute_names

      def initialize(table, attribute_names, referenced_object_type_name, referenced_attribute_names, options, &block)
        @table, @attribute_names, @referenced_object_type_name, @referenced_attribute_names =
          table, attribute_names, referenced_object_type_name, referenced_attribute_names
        super(options, &block)
        # Ensure that the attributes exist
        attribute_names.each { |a| table.parent.attribute_by_name(a) }
        # Ensure that the remote attributes exist on remote type
        referenced_attribute_names.each { |a| referenced_object_type.attribute_by_name(a) }
      end

      attr_writer :name

      def name
        if @name.nil?
          @name = "#{attribute_names.join('_')}"
        end
        @name
      end

      def referenced_object_type
        table.parent.data_module.object_type_by_name(referenced_object_type_name)
      end

      def on_update=(on_update)
        error("on_update #{on_update} on #{name} is invalid") unless ACTION_MAP.keys.include?(on_update)
        @on_update = on_update
      end

      def on_update
        @on_update ||= :no_action
      end

      def on_delete=(on_delete)
        error("on_delete #{on_delete} on #{name} is invalid") unless ACTION_MAP.keys.include?(on_delete)
        @on_delete = on_delete
      end

      def on_delete
        @on_delete ||= :no_action
      end

      def foreign_key_name
        "FK_#{s(table.parent.name)}_#{s(name)}"
      end

      def qualified_foreign_key_name
        "#{table.parent.data_module.sql.schema}.#{foreign_key_name}"
      end

      def invariant?
        true
      end

      def constraint_name
        foreign_key_name
      end
    end

    class Constraint < SqlElement
      attr_reader :name
      attr_accessor :sql

      def initialize(parent, name, options = {}, &block)
        @name = name
        super(parent, options, &block)
      end
      
      attr_writer :invariant

      # Return true if this constraint should always be true, not just on insert or update.
      def invariant?
        @invariant.nil? ? true : @invariant
      end

      def constraint_name
        "CK_#{s(parent.parent.name)}_#{s(name)}"
      end

      def qualified_constraint_name
        "#{parent.parent.data_module.sql.schema}.#{constraint_name}"
      end
    end

    class FunctionConstraint < SqlElement
      attr_reader :name
      attr_accessor :positive_sql
      attr_accessor :parameters
      attr_accessor :common_table_expression

      def initialize(parent, name, parameters, options = {}, & block)
        @name = name
        @parameters = parameters
        super(parent, options, & block)
      end

      attr_writer :invariant

      # Return true if this constraint should always be true, not just on insert or update. 
      def invariant?
        @invariant.nil? ? true : @invariant
      end

      def constraint_name
        "CK_#{s(parent.parent.name)}_#{s(name)}"
      end

      def qualified_constraint_name
        "#{parent.parent.data_module.sql.schema}.#{constraint_name}"
      end
    end

    class Validation < SqlElement
      attr_reader :name
      attr_accessor :negative_sql
      attr_accessor :common_table_expression
      attr_accessor :guard
      attr_accessor :after
      attr_accessor :instead_of

      def initialize(parent, name, options = {}, &block)
        @name = name
        super(parent, options, &block)
      end
    end

    class Trigger < SqlElement
      VALID_AFTER = [:insert, :update, :delete]

      attr_reader :name
      attr_accessor :sql
      attr_reader :after
      attr_reader :instead_of

      def initialize(parent, name, options = {}, &block)
        @name = name
        @after = [:insert, :update]
        @instead_of = []
        super(parent, options, &block)
      end

      def after=(after)
        @after = scope("after", after)
      end

      def instead_of=(instead_of)
        @instead_of = scope("instead_of", instead_of)
      end

      def trigger_name
        @trigger_name = sql_name(:trigger, "#{parent.parent.name}#{self.name}") unless @trigger_name
        @trigger_name
      end

      def qualified_trigger_name
        "#{parent.parent.data_module.sql.schema}.#{trigger_name}"
      end

      private

      def scope(label, scope)
        if scope.nil?
          scope = []
        elsif !scope.is_a?(Array)
          scope = [scope]
        end
        scope.each do |a|
          raise "Unknown #{label} specififier #{a}" unless VALID_AFTER.include?(a)
        end
        scope
      end
    end

    class Table < SqlElement
      attr_writer :table_name
      attr_accessor :partition_scheme

      #+force_overflow_for_large_objects+ if set to true will force the native *VARCHAR(max) and XML datatypes (i.e.
      # text attributes to always be stored in overflow page by database engine. Otherwise they will be stored inline
      # as long as the data fits into a 8,060 byte row. It is a performance hit to access the overflow table so this
      # should be set to false unless the data columns are infrequently accessed relative to the other columns
      attr_accessor :force_overflow_for_large_objects

      def initialize(parent, options = {}, &block)
        @indexes = Domgen::OrderedHash.new
        @constraints = Domgen::OrderedHash.new
        @function_constraints = Domgen::OrderedHash.new
        @validations = Domgen::OrderedHash.new
        @triggers = Domgen::OrderedHash.new
        @foreign_keys = Domgen::OrderedHash.new
        super(parent, options, &block)
      end

      def table_name
        @table_name = sql_name(:table, parent.name) unless @table_name
        @table_name
      end

      def qualified_table_name
        "#{parent.data_module.sql.schema}.#{table_name}"
      end

      def constraints
        @constraints.values
      end

      def constraint_by_name(name)
        @constraints[name.to_s]
      end

      def constraint(name, options = {}, &block)
        existing = constraint_by_name(name)
        error("Constraint named #{name} already defined on table #{qualified_table_name}") if (existing && !existing.inherited?)
        constraint = Constraint.new(self, name, options, &block)
        @constraints[name.to_s] = constraint
        constraint
      end

      def function_constraints
        @function_constraints.values
      end

      def function_constraint_by_name(name)
        @function_constraints[name.to_s]
      end

      def function_constraint(name, parameters, options = {}, &block)
        existing = function_constraint_by_name(name)
        error("Function Constraint named #{name} already defined on table #{qualified_table_name}") if (existing && !existing.inherited?)
        function_constraint = FunctionConstraint.new(self, name, parameters, options, &block)
        @function_constraints[name.to_s] = function_constraint
        function_constraint
      end

      def validations
        @validations.values
      end

      def validation_by_name(name)
        @validations[name.to_s]
      end

      def validation(name, options = {}, &block)
        existing = validation_by_name(name)
        error("Validation named #{name} already defined on table #{qualified_table_name}") if (existing && !existing.inherited?)
        validation = Validation.new(self, name, options, &block)
        @validations[name.to_s] = validation
        validation
      end

      def triggers
        @triggers.values
      end

      def trigger_by_name(name)
        @triggers[name.to_s]
      end

      def trigger(name, options = {}, &block)
        existing = trigger_by_name(name)
        error("Trigger named #{name} already defined on table #{qualified_table_name}") if (existing && !existing.inherited?)
        trigger = Trigger.new(self, name, options, &block)
        @triggers[name.to_s] = trigger
        trigger
      end

      def cluster(attribute_names, options = {}, &block)
        index(attribute_names, options.merge(:cluster => true), &block)
      end

      def indexes
        @indexes.values
      end

      def index(attribute_names, options = {}, skip_if_present = false, &block)
        index = Index.new(self, attribute_names, options, &block)
        return if @indexes[index.name] && skip_if_present
        error("Index named #{index.name} already defined on table #{qualified_table_name}") if @indexes[index.name]
        @indexes[index.name] = index
        index
      end

      def foreign_keys
        @foreign_keys.values
      end

      def foreign_key(attribute_names, referrenced_object_type_name, referrenced_attribute_names, options = {}, skip_if_present = false, &block)
        foreign_key = ForeignKey.new(self, attribute_names, referrenced_object_type_name, referrenced_attribute_names, options, &block)
        return if @indexes[foreign_key.name] && skip_if_present
        error("Foreign Key named #{foreign_key.name} already defined on table #{table_name}") if @indexes[foreign_key.name]
        @foreign_keys[foreign_key.name] = foreign_key
        foreign_key
      end

      def post_verify
        if self.partition_scheme && indexes.select{|index|index.cluster?}.empty?
          raise "Must specify a clustered index if using a partition scheme"
        end

        parent.unique_constraints.each do |c|
          index(c.attribute_names, {:unique => true}, true)
        end
        parent.codependent_constraints.each do |c|
          constraint_name = "#{parent.name}_#{c.name}_CoDep"
          constraint(constraint_name, :sql => <<SQL) unless constraint_by_name(constraint_name)
( #{c.attribute_names.collect { |name| "#{parent.attribute_by_name(name).sql.column_name} IS NOT NULL" }.join(" AND ")} ) OR
( #{c.attribute_names.collect { |name| "#{parent.attribute_by_name(name).sql.column_name} IS NULL" }.join(" AND ") } )
SQL
          copy_tags(c, constraint_by_name(constraint_name))
        end
        parent.dependency_constraints.each do |c|
          constraint_name = "#{parent.name}_#{c.name}_Dep"
          constraint(constraint_name, :sql => <<SQL) unless constraint_by_name(constraint_name)
#{parent.attribute_by_name(c.attribute_name).sql.column_name} IS NULL OR
( #{c.dependent_attribute_names.collect { |name| "#{parent.attribute_by_name(name).sql.column_name} IS NOT NULL" }.join(" AND ") } )
SQL
          copy_tags(c, constraint_by_name(constraint_name))
        end
        parent.incompatible_constraints.each do |c|
          sql = (0..(c.attribute_names.size)).collect do |i|
            candidate = c.attribute_names[i]
            str = c.attribute_names.collect { |name| "#{parent.attribute_by_name(name).sql.column_name} IS#{(candidate == name) ? ' NOT' : ''} NULL" }.join(' AND ')
            "(#{str})"
          end.join(" OR ")
          constraint_name = "#{parent.name}_#{c.name}_Incompat"
          constraint(constraint_name, :sql => sql) unless constraint_by_name(constraint_name)
          copy_tags(c, constraint_by_name(constraint_name))
        end

        parent.declared_attributes.select { |a| a.attribute_type == :i_enum }.each do |a|
          sorted_values = a.values.values.sort
          constraint_name = "#{a.name}_Enum"
          constraint(constraint_name, :sql => <<SQL) unless constraint_by_name(constraint_name)
#{a.sql.column_name} >= #{sorted_values[0]} AND
#{a.sql.column_name} <= #{sorted_values[sorted_values.size - 1]}
SQL
        end
        parent.declared_attributes.select { |a| a.attribute_type == :s_enum }.each do |a|
          constraint_name = "#{a.name}_Enum"
          constraint(constraint_name, :sql => <<SQL) unless constraint_by_name(constraint_name)
#{a.sql.column_name} IN (#{a.values.values.collect { |v| "'#{v}'" }.join(',')})
SQL
        end
        parent.declared_attributes.select{ |a| (a.attribute_type == :s_enum || a.attribute_type == :string) && a.persistent? && !a.allow_blank? }.each do |a|
          constraint_name = "#{a.name}_NotEmpty"
          sql = "LEN( #{a.sql.column_name} ) > 0"
          constraint(constraint_name, :sql => sql ) unless constraint_by_name(constraint_name)
        end

        parent.declared_attributes.select { |a| a.set_once? }.each do |a|
          validation_name = "#{a.name}_SetOnce"
          validation(validation_name, :negative_sql => <<SQL) unless validation_by_name(validation_name)
SELECT I.ID
FROM
inserted I
JOIN deleted D ON D.ID = I.ID
WHERE
  D.#{a.sql.column_name} IS NOT NULL AND
  (
    I.#{a.sql.column_name} IS NULL OR
    D.#{a.sql.column_name} != I.#{a.sql.column_name}
  )
SQL
        end

        parent.cycle_constraints.each do |c|
          target_attribute = parent.attribute_by_name(c.attribute_name)
          target_object_type = parent.attribute_by_name(c.attribute_name).referenced_object
          scoping_attribute = target_object_type.attribute_by_name(c.scoping_attribute)

          attribute_name_path = c.attribute_name_path
          object_path = []

          object_type = parent
          attribute_name_path.each do |attribute_name_path_element|
            object_path << object_type
            other = object_type.attribute_by_name(attribute_name_path_element)
            object_type = other.referenced_object
          end

          joins = []
          next_id = "@#{target_attribute.sql.column_name}"
          last_name = "@"
          attribute_name_path.each_with_index do |attribute_name, index|
            ot = object_path[index]
            name = "C#{index}"
            if index != 0
              joins << "LEFT JOIN #{ot.sql.table_name} #{name} ON #{last_name}#{object_path[index - 1].attribute_by_name(attribute_name_path[index - 1]).sql.column_name} = #{name}.#{ot.primary_key.sql.column_name}"
              last_name = "#{name}."
            end
            next_id = "#{last_name}#{ot.attribute_by_name(attribute_name).sql.column_name}"
          end

          comparison_id = "C0.#{scoping_attribute.sql.column_name}"

          functional_constraint_name = "#{c.name}_Scope"
          if !function_constraint_by_name(functional_constraint_name)
            function_constraint(functional_constraint_name, [c.attribute_name, c.attribute_name_path[0]]) do |constraint|
              constraint.invariant = true
              constraint.positive_sql = <<SQL
SELECT 1 AS Result
FROM
  (SELECT '1' AS IgnoreMe) I
LEFT JOIN #{target_object_type.sql.table_name} C0 ON C0.#{target_object_type.primary_key.sql.column_name} = @#{parent.attribute_by_name(c.attribute_name).sql.column_name}
#{joins.join("\n")}
WHERE @#{parent.attribute_by_name(c.attribute_name).sql.column_name} IS NULL OR #{comparison_id} = #{next_id}
SQL
            end
            copy_tags(c, function_constraint_by_name(functional_constraint_name))
          end
        end

        immutable_attributes = parent.attributes.select { |a| a.persistent? && a.immutable? }
        if immutable_attributes.size > 0
          pk = parent.primary_key

          validation_name = "Immuter"
          unless validation_by_name(validation_name)
            guard = immutable_attributes.collect { |a| "UPDATE(#{a.sql.column_name})" }.join(" OR ")
            validation(validation_name, :negative_sql => <<SQL, :after => :update, :guard => guard)
SELECT I.#{pk.sql.column_name}
FROM inserted I, deleted D
WHERE
  I.#{pk.sql.column_name} = D.#{pk.sql.column_name} AND
  (
    #{immutable_attributes.collect {|a| "(I.#{a.sql.column_name} != D.#{a.sql.column_name})" }.join(" OR\n") }
  )
SQL
         end
        end

        abstract_relationships = parent.attributes.select { |a| a.reference? && a.referenced_object.abstract? }
        if abstract_relationships.size > 0
          abstract_relationships.each do |attribute|
            concrete_subtypes = {}
            attribute.referenced_object.subtypes.select { |subtype| !subtype.abstract? }.each_with_index do |subtype, index|
              concrete_subtypes["C#{index}"] = subtype
            end
            names = concrete_subtypes.keys
            validation_name = "#{attribute.name}ForeignKey"
            #TODO: Turn this into a functional validation
            if !validation_by_name(validation_name)
              guard = "UPDATE(#{q(attribute.referencing_link_name)})"
              sql = <<SQL
      SELECT I.#{parent.primary_key.sql.column_name}
      FROM
        inserted I
SQL
              concrete_subtypes.each_pair do |name, subtype|
                sql << "      LEFT JOIN #{subtype.sql.qualified_table_name} #{name} ON #{name}.ID = I.#{q(attribute.referencing_link_name)}"
              end
              sql << "      WHERE (#{names.collect { |name| "#{name}.ID IS NULL" }.join(' AND ') })"
              (0..(names.size - 2)).each do |index|
                sql << " OR\n (#{names[index] }.ID IS NOT NULL AND (#{((index + 1)..(names.size - 1)).collect { |index| "#{names[index]}.ID IS NOT NULL" }.join(' OR ') }))"
              end
              validation(validation_name, :negative_sql => sql, :guard => guard) unless validation_by_name(validation_name)
            end
          end
        end

        self.validations.each do |validation|
          trigger_name = "#{validation.name}Validation"
          next if trigger_by_name(trigger_name)
          trigger = trigger(trigger_name, :sql => <<SQL)
#{validation.guard.nil? ? '' : "IF #{validation.guard}\nBEGIN\n" }
  DECLARE @FailedValidation BIT;
#{validation.common_table_expression} SELECT @FailedValidation = 1 WHERE EXISTS (#{validation.negative_sql})
  IF (@@ERROR = 0 AND @FailedValidation = 0) GOTO done
  ROLLBACK
  RAISERROR ('Failed to pass validation check #{validation.name}', 16, 1) WITH SETERROR
done:
#{validation.guard.nil? ? '' : "END" }
SQL
          trigger.after = validation.after if validation.after
          copy_tags(validation, trigger)
        end

        parent.declared_attributes.select { |a| a.persistent? && a.reference? && !a.abstract? && !a.polymorphic? }.each do |a|
          foreign_key([a.name],
                      a.referenced_object.qualified_name,
                      [a.referenced_object.primary_key.name],
                      {:on_update => a.on_update, :on_delete => a.on_delete},
                      true)
        end

        error("#{qualified_table_name} defines multiple clustering indexes") if indexes.select { |i| i.cluster? }.size > 1
      end

      def copy_tags(from, to)
        from.tags.each_pair do |k, v|
          to.tags[k] = v
        end
      end

      def post_inherited
        indexes.each { |a| a.mark_as_inherited }
        constraints.each { |a| a.mark_as_inherited }
        function_constraints.each { |a| a.mark_as_inherited }
        validations.each { |a| a.mark_as_inherited }
        triggers.each { |a| a.mark_as_inherited }
        foreign_keys.each { |a| a.mark_as_inherited }
      end
    end

    class Column < SqlElement
      TYPE_MAP = {"string" => "VARCHAR",
                  "integer" => "INT",
                  "real" => "FLOAT",
                  "datetime" => "DATETIME",
                  "boolean" => "BIT",
                  "i_enum" => "INT",
                  "s_enum" => "VARCHAR"}

      def column_name
        if @column_name.nil?
          if parent.reference?
            @column_name = parent.referencing_link_name
          else
            @column_name = parent.name
          end
        end
        @column_name
      end

      attr_writer :sql_type

      def sql_type
        unless @sql_type
          if :reference == parent.attribute_type
            @sql_type = parent.referenced_object.primary_key.sql.sql_type
          elsif parent.attribute_type.to_s == 'text'
            @sql_type = "VARCHAR(MAX)"
          else
            @sql_type = q(TYPE_MAP[parent.attribute_type.to_s]) + (parent.length.nil? ? '' : "(#{parent.length})")
          end
          error("Unknown type #{parent.attribute_type} in sql_type") unless @sql_type
        end
        @sql_type
      end

      attr_writer :identity

      def identity?
        @identity = parent.generated_value? unless @identity
        @identity
      end

      attr_writer :sparse

      def sparse?
        @sparse = false unless @sparse
        @sparse
      end

      attr_accessor :default_value
    end
  end

  class Attribute
    def sql
      error("Non persistent attributes should not invoke sql config method") unless persistent?
      @sql = Domgen::Sql::Column.new(self) unless @sql
      @sql
    end
  end

  class ObjectType
    self.extensions << :sql

    def sql
      @sql = Domgen::Sql::Table.new(self) unless @sql
      @sql
    end
  end

  class DataModule
    def sql
      @sql = Domgen::Sql::SqlSchema.new(self) unless @sql
      @sql
    end
  end
end
