module CrudToolbox
  module ListView
    class Base
      attr_reader :controller, :order, :filter, :locals
      attr_accessor :show_new_button, :show_row_buttons, :xhr_url

      def initialize(controller, arel, order: '', filter: '', xhr_url: nil, locals: {})
        @controller = controller
        @order = order.blank? ? default_order : parse_order(order)
        @filter = Hash[(filter || '').split(',').map { |f| f.split '^' }]
        @arel = arel
        @xhr_url = xhr_url
        @locals = locals

        @show_new_button = true
        @show_row_buttons = true

        apply_order @order[:key], @order[:col], @order[:dir]
        apply_filter @filter
      end

      def id
        self.class.to_s.split('::')[1]
      end

      def apply_filter(filter)
        if @arel.respond_to? :where
          apply_arel_where(filter)
        else
          apply_reject(filter)
        end
      end

      def apply_arel_where(filter)
        where = {}
        filter.each do |k, v|
          # This line is also important to prevent SQL injections, as it will
          # error out on unknown columns (feature!)
          c = get_col k

          # Column doesn't exis so move on to the next one
          next if c.nil?

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

        # arel.where("`#{model.table_name}`.`#{column.to_s.singularize}` in (#{sql.join ','})")
        @arel = @arel
                .where(
                  [where.keys.map { |k| "#{k} like ?" }.join(' and ')] |
                  where.values.map { |v| "%#{v}%" }
                )
      end

      def apply_reject(filter)
        @arel = @arel.reject do |record|
          filter
          .map { |k, v| next true if record.respond_to?(k) && record.send(k).to_s.match(/#{v}/i) }
          .include? nil
        end
      end

      def parse_order(order_string)
        key, direction = order_string.split(' ')

        {
          key: key,
          col: get_col(key).try(:sort_as).presence || "`#{key}`",
          dir: direction
        }
      end

      def apply_order(key, column_sql, direction)
        # Ignore columns that can't be sorted or don't exist
        return if column_sql.to_s.start_with?('NOOP') || get_col(key).nil?

        if @arel.respond_to? :order
          apply_arel_order(column_sql, direction)
        elsif @arel.is_a? Hash
          # TODO: (contractees)
        else
          apply_sort(key, direction)
        end
      end

      def apply_arel_order(column_sql, direction)
        @arel = @arel.order "#{column_sql} #{direction}"
      end

      def apply_sort(key, direction)
        if direction == 'asc'
          @arel = @arel.sort { |a, b| a.send(key) <=> b.send(key) }
        else
          @arel = @arel.sort { |a, b| b.send(key) <=> a.send(key) }
        end
      end

      def get_col(name)
        cols if @_cols.nil?
        @_cols[name]
      end

      def default_order
        { key: 'id', col: 'id', dir: 'asc' }
      end

      def records
        @arel.respond_to?(:all) ? @arel.all : @arel
      end

      def record_class
        @controller.record_class
      end

      def record_name
        # self.record_class.to_s.tableize.singularize
        self.class.to_s.split('::').pop.tableize.singularize
      end

      def col_title(column)
        # I18n.t("activerecord.attributes.#{self.record_name}.#{column}")
        s_("#{record_class}|#{column.to_s.humanize}")
      end

      # Create column
      def col(header, order = false, where: nil, sort_as: nil, values: nil)
        if header.is_a? Symbol
          order = header if order == false
          header = col_title header
        end

        Column.new header, order: order, where: where, sort_as: sort_as, values: values
      end

      # Create a "empty" column without header; useful for buttons and the like
      def empty_col
        # We need the :order parameter here because self.cols uses this as a hash
        # key
        col(nil, SecureRandom.hex)
      end

      def cols(merge = [])
        return @_cols.values if @_cols.present?

        cols = [Column.new(nil, klass: 'button-col')] + merge
        @_cols = {}.with_indifferent_access
        cols.each { |c| @_cols[c.order] = c }
        cols
      end

      def row_buttons(_record)
        []
      end

      def header_buttons
      end

      def checkboxes
      end

      def path_prefix
      end

      def paths(record)
        {
          show: [path_prefix, (record || @record)].compact,
          edit: [:edit, path_prefix, (record || @record)].compact,
          new: [:new, path_prefix, record_name].compact,
          index: [path_prefix, record_name.pluralize].compact
        }
      end

      def enum_col(model, column, translate_value = true)
        column_p = column.to_s.pluralize
        values = model.send column_p

        if translate_value
          tr_values = Hash[values.map do |k, v|
            [helpers.attr_t("#{model.to_s.underscore}.#{column_p}.#{k}"), v]
          end]
        else
          tr_values = values
        end

        col(column, column, values: tr_values.keys, where: lambda do |arel, value|
          sql = []
          tr_values.each { |k, v| sql << v if k.match(/#{value}/i) }

          if sql.length > 0
            arel.where "`#{model.table_name}`.`#{column.to_s.singularize}` in (#{sql.join ','})"
          # No matches, don't show anything
          else
            arel.none
          end
        end)
      end

      ## ActionView Helpers

      def helpers
        @controller.view_context
      end

      def params
        @controller.params
      end

      def a(str, url, options = nil)
        helpers.link_to str, url, options
      end
    end
  end
end
