require 'redmine'

if Rails::VERSION::MAJOR < 3
  require 'dispatcher'
  object_to_prepare = Dispatcher
else
  object_to_prepare = Rails.configuration
  # if redmine plugins were railties:
  # object_to_prepare = config
end
zeitwerk_enabled = Rails.version > '6.0' && Rails.autoloaders.zeitwerk_enabled?
object_to_prepare.__send__(zeitwerk_enabled ? :after_initialize : :to_prepare) do
  require_dependency File.expand_path('../lib/backlogs/nested_set_patch', __FILE__)
  require_dependency File.expand_path('../lib/backlogs/active_record', __FILE__)
  require_dependency File.expand_path('../lib/backlogs', __FILE__)
  require_dependency 'issue'

  if Issue.const_defined? "SAFE_ATTRIBUTES"
    Issue::SAFE_ATTRIBUTES << "story_points"
    Issue::SAFE_ATTRIBUTES << "position"
    Issue::SAFE_ATTRIBUTES << "remaining_hours"
  else
    Issue.safe_attributes "story_points", "position", "remaining_hours"
  end

  if (Redmine::VERSION::MAJOR > 2) || (Redmine::VERSION::MAJOR == 2 && Redmine::VERSION::MINOR >= 3)
    require_dependency File.expand_path('../lib/backlogs/time_report_patch', __FILE__)
  end
  require_dependency File.expand_path('../lib/backlogs/issue_query_patch', __FILE__)
  require_dependency File.expand_path('../lib/backlogs/issue_patch', __FILE__)
  require_dependency File.expand_path('../lib/backlogs/issue_status_patch', __FILE__)
  require_dependency File.expand_path('../lib/backlogs/tracker_patch', __FILE__)
  require_dependency File.expand_path('../lib/backlogs/version_patch', __FILE__)
  require_dependency File.expand_path('../lib/backlogs/project_patch', __FILE__)
  require_dependency File.expand_path('../lib/backlogs/user_patch', __FILE__)
  require_dependency File.expand_path('../lib/backlogs/custom_field_patch', __FILE__)

  require_dependency File.expand_path('../lib/backlogs/my_controller_patch', __FILE__)
  require_dependency File.expand_path('../lib/backlogs/issues_controller_patch', __FILE__)
  require_dependency File.expand_path('../lib/backlogs_projects_helper_patch', __FILE__)

  require_dependency File.expand_path('../lib/backlogs_plugin/hooks', __FILE__)

  require_dependency File.expand_path('../lib/backlogs/merged_array', __FILE__)

  require_dependency File.expand_path('../lib/backlogs_printable_cards', __FILE__)
  require_dependency File.expand_path('../lib/backlogs/linear_regression', __FILE__)

  Redmine::AccessControl.permission(:manage_versions).actions << "rb_sprints/close_completed"
end


Redmine::Plugin.register :redmine_backlogs do
  name 'Redmine Backlogs'
  author "friflaj,Mark Maglana,John Yani,mikoto20000,Frank Blendinger,Bo Hansen,stevel,Patrick Atamaniuk"
  description 'A plugin for agile teams'
  version 'v1.0.7'

  settings :default => {
                         :story_trackers            => nil,
                         :default_story_tracker     => nil,
                         :task_tracker              => nil,
                         :card_spec                 => nil,
                         :story_close_status_id     => '0',
                         :taskboard_card_order      => 'story_follows_tasks',
                         :story_points              => "1,2,3,5,8",
                         :show_burndown_in_sidebar  => 'enabled',
                         :show_project_name         => nil,
                         :scrum_stats_menu_position => 'top',
                         :show_redmine_std_header   => 'enabled',
                         :show_priority             => nil
                       },
           :partial => 'backlogs/settings'

  project_module :backlogs do
    # SYNTAX: permission :name_of_permission, { :controller_name => [:action1, :action2] }

    # Master backlog permissions
    permission :reset_sprint,         {
                                        :rb_sprints           => :reset
                                      }
    permission :configure_backlogs,   { :rb_project_settings => :project_settings }
    permission :view_master_backlog,  {
                                        :rb_master_backlogs  => [:show, :menu, :closed_sprints],
                                        :rb_sprints          => [:index, :show, :download],
                                        :rb_hooks_render     => [:view_issues_sidebar],
                                        :rb_wikis            => :show,
                                        :rb_stories          => [:index, :show, :tooltip],
                                        :rb_queries          => [:show, :impediments],
                                        :rb_server_variables => [:project, :sprint, :index],
                                        :rb_burndown_charts  => [:embedded, :show, :print],
                                        :rb_updated_items    => :show
                                      }

    permission :view_releases,        {
                                        :rb_releases         => [:index, :show],
                                        :rb_sprints          => [:index, :show, :download],
                                        :rb_wikis            => :show,
                                        :rb_stories          => [:index, :show, :tooltip],
                                        :rb_server_variables => [:project, :sprint, :index],
                                        :rb_burndown_charts  => [:embedded, :show, :print],
                                        :rb_updated_items    => :show
                                      }

    permission :view_taskboards,      {
                                        :rb_taskboards       => [:current, :show],
                                        :rb_sprints          => :show,
                                        :rb_stories          => [:index, :show, :tooltip],
                                        :rb_tasks            => [:index, :show],
                                        :rb_impediments      => [:index, :show],
                                        :rb_wikis            => :show,
                                        :rb_server_variables => [:project, :sprint, :index],
                                        :rb_hooks_render     => [:view_issues_sidebar],
                                        :rb_burndown_charts  => [:embedded, :show, :print],
                                        :rb_updated_items    => :show
                                      }

    # Release permissions
    permission :modify_releases,      {
                                        :rb_releases => [:new, :create, :edit, :update, :snapshot, :destroy],
                                        :rb_releases_multiview => [:new, :show, :edit, :destroy]
                                      }

    # Sprint permissions
    # :show_sprints and :list_sprints are implicit in :view_master_backlog permission
    permission :create_sprints,      { :rb_sprints => [:new, :create]  }
    permission :update_sprints,      {
                                        :rb_sprints => [:edit, :update, :close],
                                        :rb_wikis   => [:edit, :update]
                                      }

    # Story permissions
    # :show_stories and :list_stories are implicit in :view_master_backlog permission
    permission :create_stories,         { :rb_stories => :create }
    permission :update_stories,         { :rb_stories => :update }

    # Task permissions
    # :show_tasks and :list_tasks are implicit in :view_sprints
    permission :create_tasks,           { :rb_tasks => [:new, :create]  }
    permission :update_tasks,           { :rb_tasks => [:edit, :update] }

    permission :update_remaining_hours, { :rb_tasks => [:edit, :update] }

    # Impediment permissions
    # :show_impediments and :list_impediments are implicit in :view_sprints
    permission :create_impediments,     { :rb_impediments => [:new, :create]  }
    permission :update_impediments,     { :rb_impediments => [:edit, :update] }

    permission :subscribe_to_calendars,  { :rb_calendars  => :ical }
    permission :view_scrum_statistics,   { :rb_all_projects => :statistics }
  end

  menu :project_menu, :rb_master_backlogs, { :controller => :rb_master_backlogs, :action => :show }, :caption => :label_backlogs, :after => :roadmap, :param => :project_id, :if => Proc.new { Backlogs.configured? }
  menu :project_menu, :rb_taskboards, { :controller => :rb_taskboards, :action => :current }, :caption => :label_task_board, :after => :rb_master_backlogs, :param => :project_id, :if => Proc.new {|project| Backlogs.configured? && project && project.active_sprint }
  menu :project_menu, :rb_releases, { :controller => :rb_releases, :action => :index }, :caption => :label_release_plural, :after => :rb_taskboards, :param => :project_id, :if => Proc.new { Backlogs.configured? }

  menu :top_menu, :rb_statistics, { :controller => :rb_all_projects, :action => :statistics}, :caption => :label_scrum_statistics,
    :if => Proc.new { 
      Backlogs.configured? &&
      User.current.allowed_to?({:controller => :rb_all_projects, :action => :statistics}, nil, :global => true) &&
      (Backlogs.setting[:scrum_stats_menu_position].nil? || Backlogs.setting[:scrum_stats_menu_position] == 'top')
    }
  menu :application_menu, :rb_statistics, { :controller => :rb_all_projects, :action => :statistics}, :caption => :label_scrum_statistics,
    :if => Proc.new { 
      Backlogs.configured? &&
      User.current.allowed_to?({:controller => :rb_all_projects, :action => :statistics}, nil, :global => true) &&
      Backlogs.setting[:scrum_stats_menu_position] == 'application'
    }
end
