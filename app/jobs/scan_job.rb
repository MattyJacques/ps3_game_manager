class ScanJob < ApplicationJob
  queue_as :default

  def perform(scan_id)
    scan = Scan.find(scan_id)

    Library::Scanner.new.call(scan: scan) do |current_path, files_processed|
      Turbo::StreamsChannel.broadcast_replace_to(
        "scan_status",
        target: "scan_status",
        partial: "scans/scan_status",
        locals: { scan: scan, current_path: current_path, files_processed: files_processed }
      )
    end

    Turbo::StreamsChannel.broadcast_replace_to(
      "scan_status",
      target: "scan_status",
      partial: "scans/scan_status",
      locals: { scan: scan.reload, current_path: nil, files_processed: scan.files_found }
    )
  rescue StandardError => error
    scan&.fail!(summary: error.message)
    raise
  end
end
