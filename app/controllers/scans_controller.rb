class ScansController < ApplicationController
  def create
    scan = Scan.create!(status: "running", started_at: Time.current, summary: "Queued scan")
    ScanJob.perform_later(scan.id)

    redirect_to root_path, notice: "Scan queued"
  end
end
