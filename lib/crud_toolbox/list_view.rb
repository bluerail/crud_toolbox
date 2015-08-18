module CrudToolbox::ListView; end

class CrudToolbox::ListView::Base
  class Col
    attr_reader :header, :order, :where, :class, :sort_as, :values

    def initialize header, order: nil, where: nil, klass: nil, sort_as: nil, values: nil
      @header = header
      @order = order
      @where = where
      @class = klass
      @sort_as = sort_as
      @values = values
    end
  end


  attr_reader :controller, :order, :filter, :locals
  attr_accessor :show_new_button, :show_row_buttons, :xhr_url

  def initialize controller, arel, order: {}, filter: {}, xhr_url: nil, locals: {}
    @order = {}
    @filter = {}
    @controller = controller
    @arel = arel
    @xhr_url = xhr_url
    @locals = locals

    @show_new_button = true
    @show_row_buttons = true

    apply_filter filter
    apply_order order
  end


  def id
    self.class.to_s.split('::')[1]
  end


  def apply_filter filter
    if filter.present?
      filter.split(',').each do |f|
        f = f.split '^'
        @filter[f[0]] = f[1]
      end
    end

    if @arel.respond_to? :where
      where = {}
      @filter.each do |k, v|
        # This line is also important to prevent SQL injections, as it will
        # error out on unknown columns (feature!)
        c = get_col k

        # Columns doesn't exist...
        return if c.nil?

        if k.in? record_class.columns.map(&:name)
          k = "`#{record_class.table_name}`.`#{k}`"
        else
          k = "`#{k}`"
        end

        if c.where.present?
          @arel = c.where.call @arel, v
        else
          where[k] = v
        end
      end

      #arel.where("`#{model.table_name}`.`#{column.to_s.singularize}` in (#{sql.join ','})")
      @arel = @arel
        .where(
          [where.keys.map { |k| "#{k} like ?" }.join(' and ')] |
          where.values.map { |v| "%#{v}%" }
        )
    else
      @arel = @arel.reject do |record|
        @filter
          .map { |k, v| next true if record.respond_to?(k) && record.send(k).to_s.match(/#{v}/i) }
          .include? nil
      end
    end
  end


  def apply_order order
    if order.blank?
      @order = self.default_order
    else
      @order = {
        key: order.split(' ')[0],
        col: order.split(' ')[0],
        dir: order.split(' ')[1],
      }

      # Special no-op value for columns that can't be sorted
      return if order.start_with?('NOOP')
      
      # Columns doesn't exist...
      return if self.get_col(@order[:col]).nil?

      if self.get_col(@order[:col]).sort_as.present?
        @order[:col] = self.get_col(@order[:col]).sort_as
      else
        @order[:col] = "`#{@order[:col]}`"
      end
    end

    if @arel.respond_to? :order
      @arel = @arel.order "#{@order[:col]} #{@order[:dir]}"
    else
      if @arel.is_a? Hash
        # TODO (contractees)
      else
        if @order[:dir] == 'asc'
          @arel = @arel.sort { |a, b| a.send(@order[:key]) <=> b.send(@order[:key]) }
        else
          @arel = @arel.sort { |a, b| b.send(@order[:key]) <=> a.send(@order[:key]) }
        end
      end
    end
  end


  def get_col name
    self.cols if @_cols.nil?
    @_cols[name]
  end


  def default_order
    { key: 'id', col: 'id', dir: 'asc', }
  end


  def records
    @arel.respond_to?(:all) ? @arel.all : @arel
  end


  def record_class
    controller.record_class
  end


  def record_name
    #self.record_class.to_s.tableize.singularize
    self.class.to_s.split('::').pop.tableize.singularize
  end


  def col_title column
    #I18n.t("activerecord.attributes.#{self.record_name}.#{column}")
    s_("#{self.record_class}|#{column.to_s.humanize}")
  end

  # Create column
  def col header, order=false, where: nil, sort_as: nil, values: nil
    if header.is_a? Symbol
      order = header if order == false
      header = self.col_title  header
    end

    return Col.new header, order: order, where: where, sort_as: sort_as, values: values
  end


  def cols merge=[]
    return @_cols.values if @_cols.present?

    cols = [Col.new(nil, klass: 'button-col')] + merge
    @_cols = {}.with_indifferent_access
    cols.each { |c| @_cols[c.order] = c }
    return cols
  end


  def row_buttons record
    []
  end


  def header_buttons
  end


  def checkboxes
  end


  def path_prefix
  end


  def paths record
    {
      show: [self.path_prefix, (record || @record)].compact,
      edit: [:edit, self.path_prefix, (record || @record)].compact,
      new: [:new, self.path_prefix, record_name].compact,
      index: [self.path_prefix, record_name.pluralize].compact,
    }
  end


  def enum_col model, column, translate_value=true
    column_p = column.to_s.pluralize
    values = model.send column_p

    if translate_value
      tr_values = Hash[values.map do |k, v|
        [helpers.attr_t("#{model.to_s.underscore}.#{column_p}.#{k}"), v]
      end]
    else
      tr_values = values
    end

    col(column, column, values: tr_values.keys, where: -> (arel, value) {
      sql = []
      tr_values.each { |k, v| sql << v if k.match(/#{value}/i) }

      if sql.length > 0
        arel.where "`#{model.table_name}`.`#{column.to_s.singularize}` in (#{sql.join ','})"
      # No matches, don't show anything
      else
        arel.none
      end
    })
  end


  def enum_col_where model, column, value, arel, translate_value=true
  end

  ## ActionView Helpers

  def helpers
    @controller.view_context
  end


  def params
    @controller.params
  end


  def a str, url, options=nil
    helpers.link_to str, url, options
  end
end
