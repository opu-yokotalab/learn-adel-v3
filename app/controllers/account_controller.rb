class AccountController < ApplicationController
  # Be sure to include AuthenticationSystem in Application Controller instead
  include AuthenticatedSystem
  # If you want "remember me" functionality, add this before_filter to Application Controller
  before_filter :login_from_cookie

  # say something nice, you goof!  something sweet.
	def index
		redirect_to(:action => 'signup') unless logged_in? || User.count > 0
		
		@seqList=[]
		i=0
		if session[:user]
			seqs = EntSeq.find(:all,:order=>"id")
			seqs.each do |seq|
				@seqList[i] = [seq.id,seq.seq_title.toutf8]
				i+=1
			end
		end
	end

  def login
    return unless request.post?
    self.current_user = User.authenticate(params[:login], params[:password])
    if logged_in?
      if params[:remember_me] == "1"
        self.current_user.remember_me
        cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
      end
      redirect_back_or_default(:controller => '/account', :action => 'index')
      flash[:notice] = "ログインしました。"
    end
  end

  def change_passwd_method
    self.current_user.password = params[:password]
    self.current_user.password_confirmation = params[:password_confirmation]
    begin
      self.current_user.save!
      flash[:notice] = 'パスワードを変更しました。'
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = "パスワードを変更できませんでした: #{e}" 
    end
    redirect_back_or_default(:contoller => '/account', :action => 'index')
  end

	def change_email_method
		self.current_user.email = params[:email]
		begin
			self.current_user.save!
			flash[:notice] = 'メールアドレスを変更しました。'
		rescue ActiveRecord::RecordInvalid => e
			flash[:error] = "メールアドレスを変更できませんでした: #{e}"
		end
		redirect_back_or_default(:contoller => '/account', :action => 'index')
	end

  def signup
    @user = User.new(params[:user])
    return unless request.post?
    @user.save!
    self.current_user = @user
    redirect_back_or_default(:controller => '/account', :action => 'index')
    flash[:notice] = "ユーザを登録しました。"
  rescue ActiveRecord::RecordInvalid
    render :action => 'signup'
  end
  
  def logout
    self.current_user.forget_me if logged_in?
    cookies.delete :auth_token
    reset_session
    flash[:notice] = "ログアウトしました。"
    redirect_back_or_default(:controller => '/account', :action => 'index')
  end
end
