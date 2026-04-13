module Admin
  class OrganizationsController < BaseController
    before_action :set_organization, only: [ :edit, :update ]

    def index
      @organizations = Organization.order(:name)
      @organization = Organization.new(active: true)
    end

    def create
      @organization = Organization.new(organization_params)

      if @organization.save
        redirect_to admin_organizations_path, notice: "伝道会を登録しました。"
      else
        @organizations = Organization.order(:name)
        render :index, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @organization.update(organization_params)
        redirect_to admin_organizations_path, notice: "伝道会を更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private
      def set_organization
        @organization = Organization.find(params[:id])
      end

      def organization_params
        params.require(:organization).permit(:name, :active)
      end
  end
end
