require "#{File.dirname(__FILE__)}/domgen/domgen.rb"

schema_set = Domgen::SchemaSet.new do |ss|
  ss.define_schema("core") do |s|

  s.java.package = 'epwp.model'
  s.sql.schema = 'dbo'

  s.define_object_type(:CodeSetValue) do |t|
    t.integer(:ID, :primary_key => true)
    t.string(:AttributeName, 255)
    t.string(:Value, 255)
    t.string(:ParentAttributeValue, 255, :nullable => true)

    t.sql.cluster([:AttributeName,:ParentAttributeValue])

    t.jpa.query("AttributeName",
                "SELECT C FROM CodeSetValue C WHERE C.AttributeName = :AttributeName",
                :query_type => :full)
    t.jpa.query("AttributeNameAndParentAttributeValue", <<JPQL)
AttributeName = :AttributeName AND
ParentAttributeValue = :ParentAttributeValue
JPQL
  end

  s.define_object_type(:FireDistrict) do |t|
    t.integer(:ID, :primary_key => true)
    t.string(:Name, 255)
    t.sql.index([:Name])
    t.java.label_attribute = :Name
  end

  s.define_object_type(:User) do |t|
    t.integer(:ID, :primary_key => true)
    t.boolean(:Active)
    t.string(:Password, 40)
    t.string(:Salt, 40, :validate => false)
    t.string(:Email, 255, :unique => true, :validate => false)
    t.string(:FirstName, 100)
    t.string(:LastName, 100)
    t.string(:PreferredName, 100)
    t.java.label_attribute = :Email
  end

  s.define_object_type(:Submission) do |t|
    t.integer(:ID, :primary_key => true)
    t.reference(:User, :immutable => true)
    t.reference(:Submission,
                :name => :PriorSubmission,
                :immutable => true,
                :nullable => true,
                :inverse_relationship_type => :has_one,
                :inverse_relationship_name => :NextSubmission)
    t.string(:Name, 255, :nullable => true)
    t.string(:ABN, 255, :nullable => true)
    t.text(:Notes, :nullable => true)
    t.text(:Comment, :nullable => true)
    t.java.debug_attributes = [:Name, :ABN, :User, :PriorSubmission]
  end

  s.define_object_type(:Location) do |t|
    t.integer(:ID, :primary_key => true)
    t.reference(:Submission, :immutable => true)
    t.boolean(:IsPrimary)
    t.string(:PostalName, 255)
    t.string(:Address, 255)
    t.string(:Town, 100)
    t.string(:State, 30)
    t.string(:Postcode, 8)
    t.string(:Phone, 30)
    t.string(:DX, 30, :nullable => true)
    t.sql.validation(:SinglePrimaryLocationPerSubmission, :sql => <<SQL)
/* Each Submission should be associated 0 or 1 primary Locations. */
SELECT I.SubmissionID
FROM inserted I, tblLocation Other
WHERE I.ID <> Other.ID AND I.SubmissionID = Other.SubmissionID AND I.IsPrimary = 1 AND Other.IsPrimary = 1
GROUP BY I.SubmissionID
HAVING COUNT(*) > 0
SQL
  end

  s.define_object_type(:Resource) do |t|
    t.integer(:ID, :primary_key => true)
    t.reference(:Location, :nullable => true)
  end

  s.define_object_type(:Image) do |t|
    t.integer(:ID, :primary_key => true)
    t.reference(:Resource, :immutable => true)
    t.reference(:Image, :name => 'Parent', :immutable => true, :inverse_relationship_name => 'children')
    t.string(:ContentType, 20, :immutable => true)
    t.string(:Filename, 100, :immutable => true)
    t.string(:Thumbnail, 100, :immutable => true)
    t.integer(:Size, :immutable => true)
    t.integer(:Width, :immutable => true)
    t.integer(:Height, :immutable => true)
    t.string(:Description, 100, :nullable => true)
  end

  s.define_object_type(:Backhoe) do |t|
    t.integer(:ID, :primary_key => true)
    t.string(:Registration, 50)
    t.integer(:YearOfManufacture)
    t.string(:BackhoeMake, 100)
    t.string(:BackhoeModel, 100)
    t.integer(:Weight, :nullable => true)
    t.integer(:KwRating, :nullable => true)
    t.boolean(:Lights, :nullable => true)
    t.boolean(:ROPS, :nullable => true)
    t.boolean(:OGP, :nullable => true)
    t.text(:Comment, :nullable => true)
    t.reference(:Submission, :immutable => true)
    t.reference(:Resource, :immutable => true, :inverse_relationship_type => :none)
  end

=begin
  s.define_object_type(:AttributeType, :table => :tblAttributeType, :metadataThatCanChange => true) do |t|
    t.string(:ID, 50, :primary_key => true)
    t.i_enum(:DataType, {"STRING" => 1,
                         "TEXT" => 2,
                         "NUMBER" => 3,
                         "DATE" => 4,
                         "CODE_SET_VALUE" => 5,
                         "COMPARABLE_CODE_SET_VALUE" => 6,
                         "CAPABILITY" => 7,
                         "URL" => 8,
                         "BOOLEAN" => 9})
    t.attribute(:IsAsGoodAsCache, "List", :nullable => true, :persistent => false)
    t.attribute(:SubstituteCache, "List", :nullable => true, :persistent => false)

    t.sql.constraint(:DataType, :sql => "DataType IN (1, 2, 3, 4, 5, 6, 7, 8, 9)")
  end

  s.define_object_type(:CodeSetValue) do |t|
    t.integer(:DisplayRank).validators do |v|
      v.message = 'V should a year between 1990 and 2000'
      v.betweeen(1990,2000)
    end
  end

  s.define_object_type(:Attribute) do |t|
    t.reference(:CodeSetValue, :nullable => true)
    t.string(:Value, 50, :nullable => true)
    t.string(:ValueDesc, 50, :nullable => true)

    t.codependent_constraint("value", [:Value, :ValueDesc])
    t.incompatible_constraint("value", [:Value, :CodeSetValue])
  end
=end
  end
  ss.define_schema("iris") do |s|
    s.java.package = 'epwp.iris'
    s.sql.schema = 'Resource'


    s.define_object_type(:Task, :abstract => true) do |t|
      t.integer(:ID, :primary_key => true)
      t.string(:Name, 50)
    end

    s.define_object_type(:SpecificTask, :extends => :Task, :final => false) do |t|
      t.string(:STName, 50)
    end

    s.define_object_type(:ManagementProject, :extends => :SpecificTask) do |t|
      t.string(:MPName, 50)
    end


    s.define_object_type(:DeployableUnitType, :abstract => true) do |t|
      t.integer(:ID, :primary_key => true)
      t.string(:Name, 50)
    end

    s.define_object_type(:CrewType, :extends => :DeployableUnitType) do |t|
      t.string(:CrewName, 50)
    end

    s.define_object_type(:PhysicalUnitType, :extends => :DeployableUnitType) do |t|
      t.string(:PhysicalUnitName, 50)
    end

    s.define_object_type(:DeployableUnit, :abstract => true) do |t|
      t.integer(:ID, :primary_key => true)
      t.reference(:DeployableUnitType, :name => :IsOfType, :immutable => true, :abstract => true)
      t.string(:Name, 50)
      t.reference(:ManagementProject, :name => :IsMemberOfPool, :inverse_relationship_name => :PoolMember, :nullable => true)
      t.reference(:ManagementProject, :name => :IsBasedAt, :inverse_relationship_name => :BaseMember)
    end

    s.define_object_type(:PhysicalUnit, :extends => :DeployableUnit) do |t|
      t.integer(:Foo)
      t.reference(:PhysicalUnitType, :name => :IsOfType, :immutable => true)
    end

    s.define_object_type(:Crew, :extends => :DeployableUnit) do |t|
      t.integer(:Bar)
      t.reference(:CrewType, :name => :IsOfType, :immutable => true)
    end


  end
end

Domgen::Generator.generate(schema_set, 'target/generated')
