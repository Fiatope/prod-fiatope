class Project
  def permalink(*)
    'forty-two'
  end

  def user
    @user ||= User.new
  end
end
