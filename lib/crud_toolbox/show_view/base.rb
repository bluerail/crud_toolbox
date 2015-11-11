module CrudToolbox
  module ShowView
    class Base
      attr_accessor :attributes, :header, :record

      def initialize(controller, record)
        @controller = controller
        @record = record
        @attributes = []
        set_attributes
      end

      def helpers
        @controller.view_context
      end

      def params
        @controller.params
      end

      def row(attr, label = nil, blank_value = nil)
        value = if attr.is_a? Symbol
                  @record.send attr
                elsif attr.respond_to? :call
                  attr
                else
                  attr.to_s
                end
        label = if label.nil?
                  helpers.attr_t "#{@controller.record_name}.#{attr}"
                elsif label.is_a? Symbol
                  helpers.attr_t "#{@controller.record_name}.#{label}"
                else
                  label
                end

        value = blank_value if value.nil?
        @attributes << {
          label: label,
          value: value
        }
      end

      def seperator
        @attributes << { label: nil, value: '&nbsp;'.html_safe }
      end

      def caption
      end
    end
  end
end
