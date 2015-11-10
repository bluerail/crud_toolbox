module CrudToolbox
  module Controller
    extend ActiveSupport::Concern

    require 'pundit'

    included do
      include Pundit

      protect_from_forgery with: :exception
      before_action :load_resource
      before_action :set_paths
    end

    # Get the +params+ for this record
    def record_params
      return {} if params[record_name].nil?

      if self.use_form_this?
        params.require(record_name).permit!.merge fixed_params
      else
        params.require(record_name).permit allowed_fields
      end
    end

    def fixed_params
      {}
    end

    def allowed_fields
      []
    end

    # Apply pagination to the +list+
    def apply_pagination(list)
      list = Kaminari.paginate_array list if list.is_a? Array
      list.page(params[:page] || 1).per(params[:per])
    end

    # Get the name of the associated ActiveRecord; usually this can be inferred,
    # but in rare cases you could overwrite it
    def record_name
      params[:controller].split('/').pop.downcase.singularize
    end

    # Get the ActiveRecord class
    def record_class
      name = record_name.capitalize
      # Replace underscores
      name.match(/_[a-z]/).to_a.each { |m| name = name.sub m, m[1].upcase }
      Object.const_get name
    end

    # Get the FormThis! class
    def form_class
      name = record_name.capitalize
      # Replace underscores
      name.match(/_[a-z]/).to_a.each { |m| name = name.sub m, m[1].upcase }
      Object.const_get "#{name}Form"
    end

    # Human readable name
    def model_title
      # @_title ||= I18n.t(self.record_class).capitalize
      @_title ||= _(record_class.to_s.titleize.humanize)
    end

    def path_prefix
    end

    # Assign +@paths+; this function is run once with +before_action+, which is
    # usually okay. However, if you change +@record+ or +@form+ in your action,
    # you need to re-run this again to set the correct path.
    def set_paths(record = nil)
      @paths = {
        form: [path_prefix, use_form_this? ? @form : (record || @record)].compact,
        show: [path_prefix, (record || @record)].compact,
        edit: [:edit, path_prefix, (record || @record)].compact,
        new: [:new, path_prefix, record_name].compact,
        index: [path_prefix, record_name.pluralize].compact
      }
    end

    # GET /record/:id
    def show
      unless @show_view.present?
        klass = "ShowView::#{record_class}".safe_constantize
        @show_view = klass.new self, @record unless klass.nil?
      end

      respond_to do |format|
        format.html
        # TODO: Maybe we want to render the @show_view, rather than the @record?
        format.json { render json: @record }
      end
    end

    # GET /record/:id/edit
    def edit
    end

    # GET /record/new
    def new
    end

    # GET /records
    def index
      unless @list_view.present?
        klass = "ListView::#{record_class}".safe_constantize
        unless klass.nil?
          # Ignore params if they're intended for a different class
          if !formats.include?(:json) && params[:tbl_id] != record_class.to_s
            @list_view = klass.new self, @records
          else
            @list_view = klass.new self, @records, order: params[:order], filter: params[:filter]
          end
        end
      end

      respond_to do |format|
        format.html
        format.json { render json: list_view_json }
      end
    end

    # PATCH /record/:id
    def update
      if self.use_form_this?
        success = @form.validate(record_params) && @form.save
      else
        success = @record.update record_params
      end

      respond_to do |format|
        if success
          format.html { redirect_to @paths[:index], flash: { notice: update_okay_message } }
          format.json { head :ok }
        else
          format.html { render action: 'edit' }
          format.json { render json: @record.errors, status: :unprocessable_entity }
        end
      end
    end

    def update_okay_message
      _('%{model_title} ‘%{record}’ has been edited.') % { model_title: model_title, record: @record.to_s }
    end

    # POST /record
    def create
      if self.use_form_this?
        success = @form.validate(record_params) && @form.save
      else
        success = @record.update record_params
      end

      respond_to do |format|
        if success
          redir_to = if params[:commit_and_add_more].nil?
                       @paths[:index]
                     else
                       polymorphic_path(@paths[:new]) + '?' + (params[:commit_and_add_more].presence || '')
                     end

          format.html { redirect_to(redir_to, notice: create_okay_message) }
          format.json { render json: @record, status: :created, location: @record }
        else
          format.html { render action: 'new' }
          format.json { render json: @record.errors, status: :unprocessable_entity }
        end
      end
    end

    def create_okay_message
      _('%{model_title} ‘%{record}’ created.') % { model_title: model_title, record: @record.to_s }
    end

    # DELETE /record/:id
    def destroy
      respond_to do |format|
        if @record.destroy
          format.html { redirect_to @paths[:index], flash: { notice: destroy_okay_message } }
          format.json { head :ok }
        else
          format.html { redirect_to @paths[:show], flash: { alert: destroy_failed_message } }
          format.json { render json: @record.errors, status: :unprocessable_entity }
        end
      end
    end

    def destroy_okay_message
      _('%{model_title} ‘%{record}’ removed.') % { model_title: model_title, record: @record.to_s }
    end

    def destroy_failed_message
      _('Removing %{model_title} ‘%{record}’ failed: %{errors}') % { model_title: model_title, record: @record.to_s, errors: @record.errors[:base].join(',') }
    end

    def use_form_this?
      !!defined?(FormThis)
    end

    def use_pundit?
      true
    end

    protected

    def load_resource
      load_resource_all
      build_form if self.use_form_this?
      set_paths if @paths.nil? || @paths[:show] == [path_prefix].compact
    end

    def load_resource_all
      if params[:action] == 'index'
        load_resource_index
      elsif params[:id].present?
        load_resource_single
      else
        load_resource_new
      end
    end

    def load_resource_index
      if use_pundit?
        @records ||= apply_pagination policy_scope(record_class)
      else
        @records ||= apply_pagination record_class
      end
      instance_variable_set "@#{record_name.pluralize}", @records
    end

    def load_resource_single(id = nil)
      begin
        @record ||= record_class.find id || params[:id]
      rescue ActiveRecord::RecordNotFound
        # Don't leak info about what does and doesn't exist
        # Don't do this in development, since this can be quite confusing
        if !Rails.env.development?
          raise Pundit::NotAuthorizedError
        else
          raise
        end
      end

      authorize @record if self.use_pundit?
      instance_variable_set "@#{record_name}", @record
    end

    def load_resource_new
      @record ||= record_class.new
      authorize @record if self.use_pundit?
      instance_variable_set "@#{record_name}", @record
    end

    def build_form
      @form ||= form_class.new @record if @record.present?
    end

    def list_view_json
      tbody = render_to_string(
        partial: 'crud_toolbox/list_view_tbody',
        locals: { list_view: @list_view },
        layout: nil,
        formats: :html
      )
      buttons = render_to_string(
        partial: 'crud_toolbox/list_view_buttons',
        locals: { list_view: @list_view },
        layout: nil,
        formats: :html
      )

      {
        success: true,
        tbody: tbody,
        buttons: buttons
      }
    end
  end
end
