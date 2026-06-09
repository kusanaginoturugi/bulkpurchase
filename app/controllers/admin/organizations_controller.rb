# frozen_string_literal: true

module Admin
  class OrganizationsController < BaseController
    before_action :set_organization, only: %i[edit update destroy]

    def index
      @organizations = Organization.where(enabled: true).order(:code, :name)
      @all_organizations = Organization.order(:code, :name)
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

    def sync
      result = MasterSync.run
      redirect_to admin_organizations_path,
                  notice: "マスタから #{result.count} 件を同期しました。"
    rescue MasterSync::FetchError => e
      redirect_to admin_organizations_path, alert: "マスタ同期に失敗しました: #{e.message}"
    end

    def bulk_update_enabled
      enabled_ids = Array(params[:enabled]).map(&:to_i).to_set
      Organization.transaction do
        Organization.find_each do |organization|
          want = enabled_ids.include?(organization.id)
          organization.update!(enabled: want) if organization.enabled != want
        end
      end
      redirect_to admin_organizations_path, notice: "対象伝道会を更新しました。"
    end

    private

    def set_organization
      @organization = Organization.find(params[:id])
    end

    def organization_params
      params.require(:organization).permit(:code, :name, :active, :enabled)
    end
  end
end
