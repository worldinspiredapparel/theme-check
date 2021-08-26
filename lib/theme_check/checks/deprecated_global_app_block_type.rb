# frozen_string_literal: true
module ThemeCheck
  class DeprecatedGlobalAppBlockType < LiquidCheck
    severity :error
    category :liquid
    doc docs_url(__FILE__)

    INVALID_GLOBAL_APP_BLOCK_TYPE = "@global"
    VALID_GLOBAL_APP_BLOCK_TYPE = "@app"

    def on_schema(node)
      schema = JSON.parse(node.value.nodelist.join)

      if block_types_from(schema).include?(INVALID_GLOBAL_APP_BLOCK_TYPE)
        add_offense(
          "Deprecated '#{INVALID_GLOBAL_APP_BLOCK_TYPE}' block type defined in the schema, use '#{VALID_GLOBAL_APP_BLOCK_TYPE}' block type instead.",
          node: node
        )
      end
    rescue JSON::ParserError
      # Ignored, handled in ValidSchema.
    end

    def on_string(node)
      if node.value == INVALID_GLOBAL_APP_BLOCK_TYPE
        add_offense(
          "Deprecated '#{INVALID_GLOBAL_APP_BLOCK_TYPE}' block type, use '#{VALID_GLOBAL_APP_BLOCK_TYPE}' block type instead.",
          node: node
        )
      end
    end

    private

    def block_types_from(schema)
      schema["blocks"].map do |block|
        block.fetch("type", "")
      end
    end
  end
end