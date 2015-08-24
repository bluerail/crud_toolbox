module CrudToolbox::ShowView; end

class CrudToolbox::ShowView::Base
  attr_accessor :attributes, :record

  def initialize controller, record
    @controller = controller
    @record = record
    instance_variable_set "@#{self.record_name}", @record
    @attributes = []
    self.set_attributes
  end


  # CSS class(es) to use for the table
  #
  # table and table-condensed are Bootstrap clases
  def table_class
    'table table-condensed show-view'
  end


  # Set the <caption> element.
  #
  # If empty, no <caption> element will be rendered
  def caption
  end


  # Add a new row
  #
  # +attr+ The attribute name
  # +label+ The label to show; by default this is translated from +attr+.
  # +blank_value+ What to show if the value is +nil+
  def row attr, label: nil, nil_value: nil
    value = if attr.is_a? Symbol
              @record.send attr
            elsif attr.respond_to? :call
              attr
            else
              attr.to_s
            end
    label = if label.nil?
              helpers.attr_t "#{@controller.record_name}.#{attr.to_s}"
            elsif label.is_a? Symbol
              helpers.attr_t "#{@controller.record_name}.#{label.to_s}"
            else
              label
            end

    value = nil_value if value.nil?
    @attributes << {
      label: label,
      value: value,
    }
  end


  # Add a separator
  def seperator
    @attributes << {label: nil, value: '&nbsp;'.html_safe}
  end


  def helpers
    @controller.view_context
  end


  def params
    @controller.params
  end


  def record_name
    controller.record_name
  end


  def record_class
    controller.record_class
  end
end
