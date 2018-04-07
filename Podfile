# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'TastoryApp' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # ignore all warnings from all pods
  inhibit_all_warnings!

  # Pods for TastoryApp
  pod 'Parse', :inhibit_warnings => true
  pod 'Parse/FacebookUtils', :inhibit_warnings => true
  pod 'FacebookCore', :inhibit_warnings => true
  pod 'FacebookLogin', :inhibit_warnings => true
  pod 'FacebookShare', :inhibit_warnings => true
  pod 'Firebase/Core', :inhibit_warnings => true
  pod 'Fabric', :inhibit_warnings => true
  pod 'Crashlytics', '~> 3.10', :inhibit_warnings => true
  pod 'Branch', :inhibit_warnings => true
  pod 'AWSS3', :inhibit_warnings => true
  pod 'AWSCognito', :inhibit_warnings => true
  pod 'Texture', :inhibit_warnings => true
  pod 'SwiftyCam', :inhibit_warnings => true
  pod 'Jot', :git => 'https://github.com/biscottigelato/Jot.git', :inhibit_warnings => true
  pod 'QuadratTouch', :git => 'https://github.com/Constantine-Fry/das-quadrat.git', :branch => 'develop', :inhibit_warnings => true
  pod 'HTTPStatusCodes', '~> 3.1.2'
  pod 'RATreeView'
  pod 'TLPhotoPicker', :git => 'https://github.com/specc/TLPhotoPicker.git'
  pod 'ColorSlider', '~> 4.0'
  pod 'PryntTrimmerView', :git => 'https://github.com/specc/PryntTrimmerView.git'  
  pod 'SwiftRangeSlider'
  pod 'COSTouchVisualizer', :inhibit_warnings => true
  pod 'SVProgressHUD', :git => 'https://github.com/Tastory/SVProgressHUD.git', :inhibit_warnings => true
  
  target 'TastoryAppTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'TastoryAppUITests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'EarlGreyUnitTest' do
    project 'TastoryApp'

    use_frameworks! # Required for Swift Test Targets only
    inherit! :search_paths # Required for not double-linking libraries in the app and test targets.
    pod 'EarlGrey'
  end


end
