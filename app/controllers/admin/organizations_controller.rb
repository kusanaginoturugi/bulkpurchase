# frozen_string_literal: true

module Admin
  class OrganizationsController < BaseController
    before_action :set_organization, only: %i[edit update destroy]

    def index
      @organizations = Organization.order(:code, :name)
      @organization = Organization.new(active: true)
    end

    def create
      @organization = Organization.new(organization_params)

      if @organization.save
        redirect_to admin_organizations_path, notice: "伝道会を登録しました。"
      else
        @organizations = Organization.order(:code, :name)
        render :index, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @organization.update(organization_params)
        redirect_to admin_organizations_path, notice: "伝道会を更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @organization.destroy!
      redirect_to admin_organizations_path, notice: "伝道会を削除しました。"
    rescue ActiveRecord::DeleteRestrictionError
      redirect_to admin_organizations_path, alert: "ユーザーまたは注文がある伝道会は削除できません。無効化してください。"
    end

    private

    def set_organization
      @organization = Organization.find(params[:id])
    end

    def organization_params
      params.require(:organization).permit(:code, :name, :active)
    end
  end
end
