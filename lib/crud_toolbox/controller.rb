module CrudToolbox::Controller
  extend ActiveSupport::Concern

  require 'pundit'

  included do
    include Pundit

    ###protect_from_forgery with: :exception
    before_action :load_resource
    before_action :set_paths
  end

  
  # Get the +params+ for this record
  def record_params
    params.require(record_name).permit self.allowed_fields
  end

  
  def allowed_fields
    []
  end


  # Apply pagination to the +list+
  def apply_pagination list
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
    name = self.record_name.capitalize
    # Replace underscores
    name.match(/_[a-z]/).to_a.each { |m| name = name.sub m, m[1].upcase }
    return Object.const_get name
  end


  # Get the FormThis! class
  def form_class
    name = self.record_name.capitalize
    # Replace underscores
    name.match(/_[a-z]/).to_a.each { |m| name = name.sub m, m[1].upcase }
    return Object.const_get "#{name}Form"
  end


  # Human readable name
  def model_title
    #@_title ||= I18n.t(self.record_class).capitalize
    @_title ||= _(self.record_class.to_s.titleize.humanize)
  end


  # Assign +@paths+; this function is run once with +before_action+, which is
  # usually okay. However, if you change +@record+ or +@form+ in your action,
  # you need to re-run this again to set the correct path.
  def set_paths
    @paths = {
      form: [use_form_this? ? @form : @record],
      show: [@record],
      edit: [:edit, @record],
      new: [:new, @record],
      index: [self.record_name.pluralize],
    }
  end


  # GET /record/:id
  def show
    unless @show_view.present?
      klass = "CrudToolbox::ShowView::#{self.record_class}".safe_constantize
      @show_view = k.new self, @record unless klass.nil?
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
        table_class = record_class
      end

      klass = "CrudToolbox::ListView::#{record_class}".safe_constantize
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
      format.json { render json: @list_view}
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
        format.html { redirect_to @paths[:index], flash: {notice: self.update_okay_message} }
        format.json { head :ok }
      else
        format.html { render action: 'edit' }
        format.json { render json: @record.errors, status: :unprocessable_entity }
      end
    end
  end
  def update_okay_message
    _('%{model_title} ‘%{record}’ has been edited.') % {model_title: self.model_title, record: @record.to_s}
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
        format.html { redirect_to(params[:commit_and_add_more].nil? ? @paths[:index] : @paths[:new], notice: self.create_okay_message) }
        format.json { render json: @record, status: :created, location: @record }
      else
        format.html { render action: 'new' }
        format.json { render json: @record.errors, status: :unprocessable_entity }
      end
    end
  end
  def create_okay_message
    _('%{model_title} ‘%{record}’ created.') % {model_title: self.model_title, record: @record.to_s}
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
    _('%{model_title} ‘%{record}’ removed.') % {model_title: self.model_title, record: @record.to_s}
  end
  def destroy_failed_message
    _('Removing %{model_title} ‘%{record}’ failed: %{errors}') % {model_title: self.model_title, record: @record.to_s, errors: @record.errors[:base].join(',')}
  end


  def use_form_this?
    defined? FormThis
  end


  def use_pundit?
    true
  end


  private

    def load_resource
      load_resource_all
      build_form if self.use_form_this?
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


    def load_resource_single id=nil
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
        partial: 'crud_toolbox/index_table_tbody',
        locals: {table: @list_view},
        layout: nil,
        formats: :html
      )
      buttons = render_to_string(
        partial: 'crud_toolbox/index_table_buttons',
        locals: {table: @list_view},
        layout: nil,
        formats: :html
      )

      return {
        success: true,
        tbody: tbody,
        buttons: buttons,
      }
    end
end
