# frozen_string_literal: true

module Admin
  class UsersController < BaseController
    before_action :set_user, only: %i[edit update destroy]
    before_action :load_organizations, only: %i[index create edit update]

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

    def edit; end

    def update
      @user.assign_attributes(user_params)

      if @user.save
        redirect_to admin_users_path, notice: "ユーザーを更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: "自分自身は削除できません。"
        return
      end

      @user.destroy!
      redirect_to admin_users_path, notice: "ユーザーを削除しました。"
    rescue ActiveRecord::DeleteRestrictionError
      redirect_to admin_users_path, alert: "注文履歴があるユーザーは削除できません。無効化してください。"
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def load_organizations
      @organizations = Organization.active.order(:name)
    end

    def user_params
      params.require(:user)
            .permit(:name, :email_address, :password, :password_confirmation, :organization_id, :role, :active)
            .tap do |permitted|
              if action_name == "update" && permitted[:password].blank?
                permitted.delete(:password)
                permitted.delete(:password_confirmation)
              end
            end
    end
  end
end
