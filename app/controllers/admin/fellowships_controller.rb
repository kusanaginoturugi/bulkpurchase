# frozen_string_literal: true

module Admin
  class FellowshipsController < BaseController
    before_action :set_fellowship, only: %i[edit update destroy]

    def index
      @fellowships = Fellowship.where(enabled: true).order(:code, :name)
      @all_fellowships = Fellowship.order(:code, :name)
    end

    def edit; end

    def update
      if @fellowship.update(fellowship_params)
        redirect_to admin_fellowships_path, notice: "伝道会を更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @fellowship.destroy!
      redirect_to admin_fellowships_path, notice: "伝道会を削除しました。"
    rescue ActiveRecord::DeleteRestrictionError
      redirect_to admin_fellowships_path, alert: "ユーザーまたは注文がある伝道会は削除できません。無効化してください。"
    end

    def sync
      result = MasterSync.run
      redirect_to admin_fellowships_path,
                  notice: "マスタから #{result.count} 件を同期しました。"
    rescue MasterSync::FetchError => e
      redirect_to admin_fellowships_path, alert: "マスタ同期に失敗しました: #{e.message}"
    end

    def bulk_update_enabled
      enabled_ids = Array(params[:enabled]).map(&:to_i).to_set
      Fellowship.transaction do
        Fellowship.find_each do |fellowship|
          want = enabled_ids.include?(fellowship.id)
          fellowship.update!(enabled: want) if fellowship.enabled != want
        end
      end
      redirect_to admin_fellowships_path, notice: "対象伝道会を更新しました。"
    end

    private

    def set_fellowship
      @fellowship = Fellowship.find(params[:id])
    end

    def fellowship_params
      params.require(:fellowship).permit(:code, :name, :active, :enabled)
    end
  end
end
