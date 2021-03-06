require 'active_support/core_ext/array/wrap'

module ActiveRelation
  module Select
    def select (fields = nil, operation = nil, &block)
      deep_select(fields, operation, &block)
    end

    def distinct (distinct = true)
      distinct!
      query.distinct(distinct)
      self
    end

    protected

    def core
      query.ast.cores.first
    end

    def selected
      core.projections
    end

    def select?
      !!@select || selected.any?
    end

    def select!
      @select = true
    end

    def distinct?
      !!@distinct || !!core.set_quantifier
    end

    def distinct!
      @distinct = true
    end

    def deep_select (fields = nil, operation = nil, depth = 3, &block)
      fields           = fields_for_select(fields, operation)
      includes, fields = fields.partition { |f| self.includes.include?(f) }
      aliases          = aliases_for_fields(fields, &block)
      select!
      query.project(*aliases)
      if depth > 0
        includes.each { |i| including(i) } if depth == 3
        associations = fields.select { |f| self.associations.include?(f) }
        associations.each { |a| deep_join(a, :outer, depth - 1) }
      end
      self
    end

    def shallow_select (fields = nil, operation = nil, &block)
      deep_select(fields, operation, 0, &block)
    end

    def fields_for_select (fields = nil, operation = nil)
      default   = self.fields.keys.to_set
      available = default + associations.keys.to_set
      selected  = default.dup
      Array.wrap(fields).each_with_object(selected) do |field, s|
        unless field.is_a?(Hash)
          field = field.is_a?(Array) ? Hash[*field] : Hash[field, operation]
        end
        field.each do |f, o|
          unless node_valid?(f)
            f = f.to_s
            raise ActiveRelation::FieldNotDefined unless available.include?(f)
          end
          o = operation if o.nil? # o.nil? ? o = operation : operation = o
          select_field_for_operation(default, s, f, o)
        end
      end
    end

    def select_field_for_operation (default, selected, field, operation = nil)
      case operation
      when :include, :including, :also, :add, :+, true
        selected.add(field)
      when :exclude, :excluding, :except, :remove, :-, false
        selected.delete(field)
      when nil, :only, :default
        selected.clear if selected == default
        selected.add(field)
      else
        raise ActiveRelation::SelectFieldOperationInvalid
      end
    end
  end
end
