class UsersController < ApplicationController
  before_action :logged_in_user,          only: [:index, :edit, :update, :show]
  before_action :has_admin_access,        only: [:index]
  before_action :needs_to_update_account, only: [:show]
  before_action :correct_user,            only: [:edit, :update, :show]
  before_action :new_account,             only: [:show]

  def show
    @user = User.find(params[:id])

    if @user.manages_org?
      @owned_organization = @user.get_owned_org
      @unique_dates = Timecard.where(id: Timebook.where(organization_id: @owned_organization).pluck(:timecard_id)).order(end_date: :desc).distinct(:end_date).pluck(:end_date)
    else
      @timecard = @user.timecards.last
    end
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.admin_level = 10
    if @user.save
      @user.send_activation_email
      flash[:info] = "Please check your email to activate your account."
      redirect_to login_url
    else
      render 'new'
    end
  end

  def timecard_collection
    @user = User.find params[:user_id]
    @timecards = Timebook.where(user: @user).order("id DESC")
  end

  def edit
  end

  def update
    @user.needs_to_update_account = false
    @user.name = "#{params[:user][:f_name]} #{params[:user][:l_name]}"
    if @user.update_attributes(user_params)
      flash[:success] = "Profile Updated"
      # if setting a new name or profile pic for someone in your organization else editing youself
      if helpers.has_company_access? and helpers.manages_user(@user)
        redirect_to organization_path(@current_user.owned_organization)
      else
        redirect_to @user
      end
    else
      render 'edit'
    end
  end

  def destroy
    user = User.find params[:id]
    password = SecureRandom.urlsafe_base64

    if user.name
      user.name += " [Removed]"
    end
    user.email += " [Removed]"
    user.password = password
    user.password_confirmation = password
    user.disabled = true

    if user.save
      render json: {message: "Successfully destroyed"}
    else
      render json: {message: "Failed to destroy"}
    end
  end

  def hard_delete
    user = User.find params[:user_id]

    Employee.where(user: user).delete_all
    timecards = Timebook.where(user: user)

    timecards.each do |timebook_entry|
      Timecard.find(timebook_entry.timecard_id).destroy
    end

    Timebook.where(user: user).delete_all

    user.destroy
  end

  private
    def user_params
      params.require(:user).permit(:f_name, :l_name, :email, :password, :password_confirmation, :user_image_link)
    end

    def logged_in_user
      unless logged_in?
        store_location
        flash[:danger] = "Please Log In"
        redirect_to login_url
      end
    end

    def needs_to_update_account
      if @current_user.needs_to_update_account
        redirect_to edit_user_path
      end
    end

    def correct_user
      @user = User.find(params[:id])
      redirect_to(@current_user) unless current_user?(@user) or has_admin_access? or helpers.manages_user(@user)
    end

    def new_account
      @user = User.find(params[:id])
      if @user.name == nil
        flash[:danger] = "Please update account info"
        render 'edit'
      end
    end

    def has_admin_access?
      @current_user.admin_level == 1
    end


end
