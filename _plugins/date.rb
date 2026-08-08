# frozen_string_literal: true

module Jekyll
  # Implements the `date` tag.
  class DateTag < Liquid::Tag
    def initialize(tag_name, input, _)
      super

      (@format, @date_source) = format(input)
      @date = variable?(@date_source) ? nil : to_date(@date_source)
    end

    def render(context)
      date = @date ||
             to_date(fixed_date(context)) ||
             to_date(lookup(context, 'page.date'))

      return '' if date.nil?

      ordinal = ordinal(date.day)
      format = (@format || default_format(ordinal)).gsub('{day}', ordinal)
      iso8601_date = date.strftime('%F')
      readable_date = date.strftime(format)

      Jekyll.logger.debug 'DateTag:', "Rendering date '#{date}' with format '#{format}'."

      "<abbr title=\"#{iso8601_date}\">#{readable_date}</abbr>"
    end

    def ordinal(day)
      day.to_s +
        case day
        when 1, 21, 31
          'st'
        when 2, 22
          'nd'
        when 3, 23
          'rd'
        else
          'th'
        end
    end

    private

    def variable?(source)
      source.is_a?(String) && source.match?(/\A[a-zA-Z_]\w*(\.\w+)*\z/)
    end

    def fixed_date(context)
      return nil if @date_source.nil? || @date_source.empty?

      lookup(context, @date_source)
    end

    def default_format(ordinal)
      "%A, %B #{ordinal} %Y"
    end

    def format(input)
      return [nil, input] if input.nil? || !input.is_a?(String) || input.empty?

      match = input.match(/format:\s*['"](.*)['"]/)

      return [nil, input] if match.nil?

      format = match[1]
      input = input.gsub(match[0], '').sub(/,\s*\z/, '').strip

      [format, input]
    end

    def to_date(date)
      if date.nil? || (date.respond_to?(:empty?) && date.empty?)
        Jekyll.logger.debug 'DateTag:', 'Date is nil or empty.'
        return nil
      end

      if date.is_a?(Date) || date.is_a?(Time)
        Jekyll.logger.debug 'DateTag:', "Date '#{date}' is already a Date or Time object."
        return date
      end

      Jekyll.logger.debug 'DateTag:', "Parsing date: #{date}."

      Date.parse(date)
    rescue StandardError => e
      Jekyll.logger.warn 'DateTag:', "Invalid date: #{date}. #{e}"
      nil
    end

    def lookup(context, name)
      Jekyll.logger.debug 'DateTag:', "Looking up '#{name}' in context."

      lookup = context
      name.split('.').each { |value| lookup = lookup[value] }

      Jekyll.logger.debug 'DateTag:', "Found '#{name}' with value: #{lookup}."

      lookup
    end
  end
end

Liquid::Template.register_tag('date', Jekyll::DateTag)
