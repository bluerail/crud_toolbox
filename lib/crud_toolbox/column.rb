module CrudToolbox
  class Column
    attr_reader :header, :order, :where, :class, :sort_as, :values

    def initialize(header, order: nil, where: nil, klass: nil, sort_as: nil, values: nil)
      @header = header
      @order = order
      @where = where
      @class = klass
      @sort_as = sort_as
      @values = values
    end
  end
end
