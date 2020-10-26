module ManageIQ
  module Api
    module OpenApi
      class Generator
        require 'json'

        OPENAPI_VERSION = "3.0.0".freeze
        PARAMETERS_PATH = "/components/parameters".freeze
        SCHEMAS_PATH    = "/components/schemas".freeze

        attr_reader :manageiq_api_path, :openapi_path, :openapi_spec

        def initialize
          manageiq_api_engine = Vmdb::Plugins.all.detect { |e| e.name == "ManageIQ::Api::Engine" }

          @manageiq_api_path = manageiq_api_engine.root
          @openapi_path      = manageiq_api_path.join("config", "openapi.json")
          @openapi_spec      = skeletal_openapi_spec
        end

        def generate!
          openapi_spec["components"]["schemas"] = build_schemas
          File.write(openapi_path, JSON.pretty_generate(openapi_spec) + "\n")
        end

        private

        def api_version
          ManageIQ::Api::VERSION
        end

        def server_base_path
          "/api(/:version)"
        end

        def build_schemas
          ::Api::ApiConfig.collections.each_with_object({}) do |(collection_name, collection), schemas|
            next unless collection.klass

            model = collection.klass.constantize

            schemas[model.name] = {
              "type"                 => "object",
              "properties"           => build_schema_properties(model),
              "additionalProperties" => false
            }
          end
        end

        def build_schema_properties(model)
          model.columns_hash.each_with_object({}) do |(key, value), properties|
            properties[key] = build_schema_properties_value(model, key, value)
          end
        end

        def build_schema_properties_value(model, key, value)
          if key == model.primary_key || key.ends_with?("_id")
            {"$ref" => "##{SCHEMAS_PATH}/ID"}
          else
            properties_value = {
              "type" => "string"
            }

            case value.sql_type_metadata.type
            when :datetime
              properties_value["format"] = "date-time"
            when :integer
              properties_value["type"] = "integer"
            when :float
              properties_value["type"] = "number"
            when :boolean
              properties_value["type"] = "boolean"
            when :jsonb
              properties_value["type"] = "object"
            end

            properties_value
          end
        end

        def schemas
          @schemas ||= {
            "ID" => {
              "type"        => "string",
              "description" => "ID of the resource",
              "pattern"     => "^\\d+$",
              "readOnly"    => true,
            }
          }
        end

        def skeletal_openapi_spec
          {
            "openapi"    => OPENAPI_VERSION,
            "info"       => {},
            "secuirty"   => [],
            "paths"      => {},
            "servers"    => [],
            "components" => {
              "parameters" => {},
              "schemas"    => {}
            },
          }
        end
      end
    end
  end
end
