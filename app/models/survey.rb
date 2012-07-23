class Survey < ActiveRecord::Base
  has_many :responses, dependent: :destroy
  has_many :sections, dependent: :destroy, order: :section_order
  has_many :questions, through: :sections

  scope :by_name, order(:name)

  validates :name, presence: true, uniqueness: {case_sensitive: false}

  def ordered_questions
    questions.sort_by { |q| [q.section.section_order, q.question_order] }
  end

  def first_section
    sections.first
  end

  def section_with_id(section_id)
    sections.find{ |s| s.id == section_id.to_i}
  end

  # find the next section after the section with the given id
  def section_id_after(section_id)
    section_ids = sections.collect(&:id)
    current_index = section_ids.index(section_id)
    raise "Didn't find any section with id #{section_id} in this survey" unless current_index
    raise "Tried to call section_id_after on last section" if current_index == (section_ids.size - 1)
    section_ids[current_index + 1]
  end

  def destroy
    # This is here as a safety measure, if we implement delete, it will need to be removed.
    if Rails.env.development? or Rails.env.test?
      super
    else
      raise "Can't destroy surveys in production! \n" +
                "Destroying a survey would destroy *all* of the questions and answers that have been associated with it."
    end
  end

  def question_with_code(code)
    populate_question_hash if @question_map.nil?
    @question_map[code.downcase]
  end

  def populate_question_hash(preload_cqvs=false)
    # optimisation used by batch processing - load all the questions once and store them in a hash keyed by question code
    # sometimes we want to preload cqvs, other times we don't, so the option is available here
    @question_map = {}
    qs = preload_cqvs ? questions.includes(:cross_question_validations).all : questions.all
    qs.each do |question|
      @question_map[question.code.downcase] = question
    end
  end
end