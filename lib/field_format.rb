module Redmine
  module FieldFormat

    class RbReleaseFormat < RecordList
      add 'found_in_release'
      self.form_partial = 'custom_fields/formats/found_in_release'
      field_attributes :found_in_release_status

      def possible_values_options(custom_field, object=nil)
        if object.is_a?(Array)
          projects = object.map { |o| o.respond_to?(:project) ? o.project : nil }.compact.uniq
          projects.map { |project| possible_values_options(custom_field, project) }.reduce(:&) || []
        elsif object.respond_to?(:project) && object.project
          scope = object.project.releases
          if custom_field.found_in_release_status.is_a?(Array)
            statuses = custom_field.found_in_release_status.map(&:to_s).reject(&:blank?)
            if statuses.any?
              scope = scope.where(:status => statuses.map(&:to_s))
            end
          end
          scope.sort.collect { |u| [u.to_s, u.id.to_s] }
        else
          []
        end
      end

      def before_custom_field_save(custom_field)
        super
        if custom_field.found_in_release_status.is_a?(Array)
          custom_field.found_in_release_status.map!(&:to_s).reject!(&:blank?)
        end
      end
    end


  end
end
