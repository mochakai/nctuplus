class User < ActiveRecord::Base
	
	belongs_to :department
	belongs_to :semester
	has_many :past_exams
	has_many :discusses
	has_many :course_content_lists
	has_many :content_list_ranks
	has_many :comments
	has_many :course_simulations

	has_many :user_coursemapships
	has_many :course_maps, :through=> :user_coursemapships

	has_many :course_teacher_ratings
	
	validates :uid, :uniqueness => {:scope => [ :student_id]}
	
	def hasFb?
		return self.provider=="facebook"
	end
	
## role func
	def isAdmin?
		return self.role==0
	end
	
	def isOffice?
		return self.role==2
	end	
	
	def isNormal?
		return self.role==1
	end
	
##	
	def is_undergrad
		self.department && self.department.degree==3
	end
	def all_courses
		self.course_simulations.includes(:course_detail, :course_teachership, :course, :course_field).where("course_detail_id != 0")
	end
	
	def courses_this_sem
		self.all_courses.where("semester_id=?",latest_semester.id)
	end
	
	def courses_taked
		self.all_courses.where("semester_id != 0")
	end
	def courses_agreed
		self.course_simulations.includes(:course_detail, :course, :course_field).where("course_detail_id != 0 AND semester_id = 0")
	end
	
	def pass_courses
		self.course_simulations.includes(:course, :course_detail).where("(semester_id !=0) AND (score = '通過' OR score>= ?)",self.pass_score)
	end
	
	
	def pass_score
		return self.is_undergrad ? 60 : 70
	end
	def total_credit
		return self.pass_courses.map{|cs|cs.course.credit.to_i}.reduce(:+)||0
	end
	
	def courses_json
		return self.all_courses.order("course_field_id DESC").map{|cs|{
			:name=>cs.course.ch_name,
			:cs_id=>cs.id,
			:course_id=>cs.course.id,
			:ct_id=>cs.course_teachership.id,
			:cos_type=>cs.cos_type=="" ? cs.course_detail.cos_type : cs.cos_type,
			:sem_id=>cs.semester_id,
			:brief=>cs.course_detail.brief,
			:credit=>cs.course.credit,
			:cf_id=>cs.course_field_id ? cs.course_field_id : 0,
			:score=>cs.semester_id==0 ? cs.memo : cs.semester_id==Semester.last.id ? "修習中" : cs.score
		}}
	end
	
	def update_omniauth(auth)
    update_attributes(
      :provider => auth.provider,
      :uid => auth.uid,
      :name => auth.info.name,
      :oauth_token => auth.credentials.token,
      :oauth_expires_at => Time.at(auth.credentials.expires_at)
    )
  end
	
  def self.from_omniauth(auth)
    where(auth.slice(:provider, :uid)).first_or_initialize.tap do |user|
      user.provider = auth.provider
      user.uid = auth.uid
      user.name = auth.info.name
      user.oauth_token = auth.credentials.token
      user.oauth_expires_at = Time.at(auth.credentials.expires_at)
      user.save!
    end
  end
  
  
  def self.e3_login(username, password)

  		return if not username and not password
require 'open-uri'
require 'net/http' 			
		sendE3={:key=>Nctuplus::Application.config.secret_key_base ,:id=>username, :pwd=>password}				
		config = YAML.load_file("#{Rails.root}/config/E3.yml")
		res = Curl.post(config["prefix_url"]+"Authentication",sendE3).body_str.to_s	
		
		if res=='"OK"'
			return {:e3_auth=>true, :user=>User.where(:student_id=>username).take}
		else
			return {:e3_auth=>false}	
  		end
  end
end