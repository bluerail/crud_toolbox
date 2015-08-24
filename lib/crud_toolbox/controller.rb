module CrudToolbox::Controller
  extend ActiveSupport::Concern

  begin
    require 'pundit'
  rescue LoadError
    # Do nothing
  end

  included do
    include Pundit

    protect_from_forgery with: :exception
    before_action :load_resource
    before_action :set_paths
  end


  # Get the +params+ for this record
  #
  # If you use FormThis!, we return all parameters. This is safe since you
  # already define attributes in the form class.
  #
  # If you don't use FormThis!, we use the value of +allowed_fields+
  #
  # Additionally, you can override +fixed_params+ to add parameters you always
  # want to be present. This is useful when you always want to include the same
  # parent object id.
  def record_params
    return {} if params[self.record_name].nil?

    if CrudToolbox.use_form_this?
      params.require(self.record_name).permit!.merge fixed_params
    else
      params.require(self.record_name).permit self.allowed_fields
    end
  end

  # Fixed parameters for this record.
  #
  # This is expected to return a Hash
  def fixed_params
    {}
  end


  # Allowed fields for this record.
  #
  # This is expected to return something that +params.permit+ understands.
  def allowed_fields
    []
  end


  # Apply pagination to the +list+
  def apply_pagination list, page_param=:page
    list = Kaminari.paginate_array list if list.is_a? Array
    list.page(params[page_param] || 1).per(params[:per])
  end


  # Get the name of the associated ActiveRecord class.
  #
  # This can usually this can be inferred from the controller name, but in some
  # cases you need to overwrite it.
  def record_name
    params[:controller].split('/').pop.downcase.singularize
  end


  # Get the ActiveRecord class
  #
  # You should almost never have to overwrite this, as it uses
  # +self.record_name+
  def record_class
    name = self.record_name.capitalize
    # Replace underscores
    name.match(/_[a-z]/).to_a.each { |m| name = name.sub m, m[1].upcase }
    return Object.const_get name
  end


  # Get the FormThis! class
  #
  # This uses +self.record_name+
  def form_class
    name = self.record_name.capitalize
    # Replace underscores
    name.match(/_[a-z]/).to_a.each { |m| name = name.sub m, m[1].upcase }
    return Object.const_get "#{name}Form"
  end


  # Human readable name for the current record.
  def record_title
    if CrudToolbox.use_gettext?
      @_title ||= _(self.record_class.to_s.titleize.humanize)
    else
      @_title ||= I18n.t(self.record_class).capitalize
    end
  end


  # Assign +@paths+; this function is run once with +before_action+, which is
  # usually okay. However, if you change +@record+ or +@form+ in your action,
  # you need to re-run this again to set the correct path.
  def set_paths record=nil
    @paths = {
      form: [self.namespace, CrudToolbox.use_form_this? ? @form : (record || @record)].compact,
      show: [self.namespace, (record || @record)].compact,
      edit: [:edit, self.namespace, (record || @record)].compact,
      new: [:new, self.namespace, self.record_name].compact,
      index: [self.namespace, self.record_name.pluralize].compact,
    }
  end

  # Set a namespace for the paths.
  #
  #   namespace :admin do
  #     .. your routes
  #   end
  #
  # We try to infer this by default
  def namespace
    ns = self.class.to_s.split('::')
    return nil if ns.length == 0
    return ns[0].downcase
  end


  # GET /record/:id
  def show
    unless @show_view.present?
      klass = "ShowView::#{self.record_class}".safe_constantize
      @show_view = klass.new self, @record unless klass.nil?
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
      if formats.include?(:json) && params[:tbl_id].present?
        table_class = params[:tbl_id]
      else
        table_class = self.record_class
      end

      klass = "ListView::#{self.record_class}".safe_constantize
      unless klass.nil?
        # Ignore params if they're intended for a different class
        if !formats.include?(:json) && params[:tbl_id] != self.record_class.to_s
          @list_view = klass.new self, @records
        else
          @list_view = klass.new self, @records, order: params[:order], filter: params[:filter]
        end
      end
    end

    respond_to do |format|
      format.html
      format.json do
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

        render json: {
          success: true,
          tbody: tbody,
          buttons: buttons,
        }
      end
    end
  end


  # PATCH /record/:id
  def update
    if CrudToolbox.use_form_this?
      success = @form.validate(record_params) && @form.save
    else
      success = @record.update record_params
    end

    respond_to do |format|
      if success
        format.html { redirect_to @paths[:index], flash: {notice: self.update_okay_message} }
        format.json { head :ok }
      else
        format.html { render action: 'edit' }
        format.json { render json: @record.errors, status: :unprocessable_entity }
      end
    end
  end
  def update_okay_message
    _('%{record_title} ‘%{record}’ has been edited.') % {record_title: self.record_title, record: @record.to_s}
  end


  # POST /record
  def create
    if CrudToolbox.use_form_this?
      success = @form.validate(record_params) && @form.save
    else
      success = @record.update record_params
    end

    respond_to do |format|
      if success
        format.html { redirect_to(params[:commit_and_add_more].nil? ? @paths[:index] : @paths[:new], notice: self.create_okay_message) }
        format.json { render json: @record, status: :created, location: @record }
      else
        format.html { render action: 'new' }
        format.json { render json: @record.errors, status: :unprocessable_entity }
      end
    end
  end
  def create_okay_message
    _('%{record_title} ‘%{record}’ created.') % {record_title: self.record_title, record: @record.to_s}
  end


  # DELETE /record/:id
  def destroy
    respond_to do |format|
      if @record.destroy
        format.html { redirect_to @paths[:index], flash: { notice: self.destroy_okay_message } }
        format.json { head :ok }
      else
        format.html { redirect_to @paths[:show], flash: { alert: self.destroy_failed_message } }
        format.json { render json: @record.errors, status: :unprocessable_entity }
      end
    end
  end
  def destroy_okay_message
    _('%{record_title} ‘%{record}’ removed.') % {record_title: self.record_title, record: @record.to_s}
  end
  def destroy_failed_message
    _('Removing %{record_title} ‘%{record}’ failed: %{errors}') % {record_title: self.record_title, record: @record.to_s, errors: @record.errors[:base].join(',')}
  end


  protected

    def load_resource
      load_resource_all
      build_form if CrudtoolBox.use_form_this?
      self.set_paths if @paths.nil? || @paths[:show] == [self.path_prefix].compact
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
      if CrudToolbox.use_pundit?
        @records ||= apply_pagination policy_scope(self.record_class)
      else
        @records ||= apply_pagination self.record_class
      end
      instance_variable_set "@#{self.record_name.pluralize}", @records
    end


    def load_resource_single id=nil
      begin
        @record ||= self.record_class.find id || params[:id]
      rescue ActiveRecord::RecordNotFound
        # Don't leak info about what does and doesn't exist
        # Don't do this in development, since this can be quite confusing
        if !Rails.env.development?
          raise Pundit::NotAuthorizedError
        else
          raise
        end
      end

      authorize @record if CrudToolbox.use_pundit?
      instance_variable_set "@#{self.record_name}", @record
    end


    def load_resource_new
      @record ||= self.record_class.new
      authorize @record if CrudToolbox.use_pundit?
      instance_variable_set "@#{self.record_name}", @record
    end


    def build_form
      @form ||= form_class.new @record if @record.present?
    end
end
