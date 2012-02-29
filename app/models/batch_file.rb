require 'csv'

class BatchFile < ActiveRecord::Base

  BABY_CODE_COLUMN = "BabyCode"
  STATUS_FAILED = "Failed"
  STATUS_SUCCESS = "Processed Successfully"
  STATUS_REVIEW = "Needs Review"
  STATUS_IN_PROGRESS = "In Progress"

  MESSAGE_WARNINGS = "The file you uploaded has one or more warnings. Please review the reports for details."
  MESSAGE_NO_BABY_CODE = "The file you uploaded did not contain a BabyCode column"
  MESSAGE_EMPTY = "The file you uploaded did not contain any data"
  MESSAGE_FAILED_VALIDATION = "The file you uploaded did not pass validation. Please review the reports for details."
  MESSAGE_SUCCESS = "Your file has been processed successfully"
  MESSAGE_BAD_FORMAT = "The file you uploaded was not a valid CSV file"

  belongs_to :survey
  belongs_to :user
  belongs_to :hospital

  has_attached_file :file, :styles => {}, :path => :make_file_path

  before_validation :set_status

  validates_presence_of :survey_id
  validates_presence_of :user_id
  validates_presence_of :hospital_id
  validates_presence_of :file_file_name

  attr_accessor :responses

  def make_file_path
    # this is a method so that APP_CONFIG has been loaded by the time is executes
    "#{APP_CONFIG['batch_files_root']}/:id.:extension"
  end

  def has_summary_report?
    !summary_report_path.blank?
  end

  def has_detail_report?
    !detail_report_path.blank?
  end

  def success?
    self.status == STATUS_SUCCESS
  end

  def process
    raise "Batch has already been processed, cannot reprocess" unless status == STATUS_IN_PROGRESS
    BatchFile.transaction do
      begin
        can_generate_report = process_batch
        if can_generate_report
          BatchReportGenerator.new(self).generate_reports
        end
      rescue ArgumentError
        logger.info("Argument error while reading file")
        # Note: Catching ArgumentError seems a bit odd, but CSV throws it when the file is not UTF-8 which happens if you upload an xls file
        set_outcome(STATUS_FAILED, MESSAGE_BAD_FORMAT)
      rescue CSV::MalformedCSVError
        logger.info("Malformed CSV error while reading file")
        set_outcome(STATUS_FAILED, MESSAGE_BAD_FORMAT)
      end
      save!
      logger.info("Finished processing file with id #{id}, status is now #{status}")
    end
  end

  def problem_record_count
    return nil if responses.nil?
    responses.collect(&:warnings?).count(true)
  end

  private

  def process_batch
    failures = false
    warnings = false
    responses = []
    logger.info("Processing batch file with id #{id}")
    processed_a_row = false
    count = 0

    CSV.foreach(file.path, {headers: true}) do |row|
      unless row.headers.include?(BABY_CODE_COLUMN)
        set_outcome(STATUS_FAILED, MESSAGE_NO_BABY_CODE)
        return false
      end
      count += 1
      processed_a_row = true
      baby_code = row[BABY_CODE_COLUMN]
      if baby_code.blank?
        failures = true
      else
        response = Response.new(survey: survey, baby_code: baby_code, user: user, hospital: hospital, submitted_status: Response::STATUS_UNSUBMITTED, batch_file: self)
        response.build_answers_from_hash(row.to_hash)
        failures = true if response.fatal_warnings?
        warnings = true if response.warnings?
        responses << response
      end
    end

    if !processed_a_row
      set_outcome(STATUS_FAILED, MESSAGE_EMPTY)
      return false
    end

    self.record_count = count
    if failures
      set_outcome(STATUS_FAILED, MESSAGE_FAILED_VALIDATION)
    elsif warnings
      set_outcome(STATUS_REVIEW, MESSAGE_WARNINGS)
    else
      responses.each do |r|
        r.submitted_status = Response::STATUS_SUBMITTED
        r.save!
      end
      set_outcome(STATUS_SUCCESS, MESSAGE_SUCCESS)
    end
    self.responses = responses
    true
  end

  def set_status
    self.status = STATUS_IN_PROGRESS if self.status.nil?
  end

  def set_outcome(status, message)
    self.status = status
    self.message = message
  end
end
