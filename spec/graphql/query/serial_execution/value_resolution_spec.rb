require "spec_helper"

describe GraphQL::Query::SerialExecution::ValueResolution do
  let(:schema) {
    day_of_week_enum = GraphQL::EnumType.define do
      name "DayOfWeek"
      value("MONDAY", value: 0)
      value("TUESDAY", value: 1)
      value("WEDNESDAY", value: 2)
      value("THURSDAY", value: 3)
      value("FRIDAY", value: 4)
      value("SATURDAY", value: 5)
      value("SUNDAY", value: 6)
    end

    interface = GraphQL::InterfaceType.define do
      name "SomeInterface"
      field :someField, !types.Int
    end

    some_object = GraphQL::ObjectType.define do
      name "SomeObject"
      interfaces [interface]
    end

    other_object = GraphQL::ObjectType.define do
      name "OtherObject"
    end

    OtherObject = Class.new

    query_root = GraphQL::ObjectType.define do
      name "Query"
      field :tomorrow, day_of_week_enum do
        argument :today, day_of_week_enum
        resolve ->(obj, args, ctx) { (args["today"] + 1) % 7 }
      end
      field :resolvesToNilInterface, interface do
        resolve ->(obj, args, ctx) { Object.new }
      end
      field :resolvesToWrongTypeInterface, interface do
        resolve ->(obj, args, ctx) { OtherObject.new }
      end
    end

    GraphQL::Schema.define do
      query(query_root)
      orphan_types [some_object]
      resolve_type ->(obj, ctx) do
        if obj.is_a?(OtherObject)
          other_object
        else
          nil
        end
      end
    end
  }

  let(:result) { schema.execute(
    query_string,
  )}

  describe "enum resolution" do
    let(:query_string) { %|
      {
        tomorrow(today: FRIDAY)
      }
    |}

    it "coerces enum input to the value and result to the name" do
      expected = {
        "data" => {
          "tomorrow" => "SATURDAY"
        }
      }
      assert_equal(expected, result)
    end
  end

  describe "interface type resolution" do
    describe "when type can't be resolved" do
      let(:query_string) { %|
        {
          resolvesToNilInterface { someField }
        }
      |}

      it "raises an error" do
        err = assert_raises(GraphQL::ObjectType::UnresolvedTypeError) { result }
        expected_message = %|The value from "resolvesToNilInterface" on "Query" could not be resolved to "SomeInterface". (Received: nil, Expected: [SomeObject])|
        assert_equal expected_message, err.message
      end
    end

    describe "when type resolves but is not a possible type of an interface" do
      let(:query_string) { %|
        {
          resolvesToWrongTypeInterface { someField }
        }
      |}

      it "raises an error" do
        err = assert_raises(GraphQL::ObjectType::UnresolvedTypeError) { result }
        expected_message = %|The value from "resolvesToWrongTypeInterface" on "Query" could not be resolved to "SomeInterface". (Received: OtherObject, Expected: [SomeObject])|
        assert_equal expected_message, err.message
      end
    end

  end
end
