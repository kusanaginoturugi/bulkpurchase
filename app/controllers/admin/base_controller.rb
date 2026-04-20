# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :require_admin!

    private

    def require_admin!
      return if current_user&.admin?

      redirect_to root_path, alert: "管理者のみ利用できます。"
    end
  end
end
