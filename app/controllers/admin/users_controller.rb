module Admin
  class UsersController < BaseController
    before_action :set_user, only: [ :edit, :update ]
    before_action :load_organizations, only: [ :index, :create, :edit, :update ]

    def index
      @users = User.includes(:organization).order(:name)
      @user = User.new(active: true, role: :user)
    end

    def create
      @user = User.new(user_params)

      if @user.save
        redirect_to admin_users_path, notice: "ユーザーを登録しました。"
      else
        @users = User.includes(:organization).order(:name)
        render :index, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @user.update(user_params)
        redirect_to admin_users_path, notice: "ユーザーを更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private
      def set_user
        @user = User.find(params[:id])
      end

      def load_organizations
        @organizations = Organization.active.order(:name)
      end

      def user_params
        params.require(:user).permit(:name, :email_address, :password, :password_confirmation, :organization_id, :role, :active)
      end
  end
end
