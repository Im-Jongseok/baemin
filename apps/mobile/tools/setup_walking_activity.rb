require 'xcodeproj'

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' }
target = project.targets.find { |t| t.name == 'WalkingActivity' } ||
  project.new_target(:app_extension, 'WalkingActivity', :ios, '16.2')
group = project.main_group.find_subpath('WalkingActivity', true)
group.path = 'WalkingActivity'
widget = group.files.find { |f| f.path == 'WalkingActivity.swift' } || group.new_file('WalkingActivity.swift')
group.new_file('Info.plist') unless group.files.any? { |f| f.path == 'Info.plist' }
assets = group.files.find { |f| f.path == 'Assets.xcassets' } || group.new_file('Assets.xcassets')
target.resources_build_phase.add_file_reference(assets, true)
font = group.files.find { |f| f.path == '../../assets/fonts/NotoSansKR.ttf' } || group.new_file('../../assets/fonts/NotoSansKR.ttf')
target.resources_build_phase.add_file_reference(font, true)
runner_group = project.main_group.find_subpath('Runner')
attributes = runner_group.files.find { |f| f.path == 'WalkingAttributes.swift' } || runner_group.new_file('WalkingAttributes.swift')
runner.source_build_phase.add_file_reference(attributes, true)
target.source_build_phase.add_file_reference(attributes, true)
target.source_build_phase.add_file_reference(widget, true)
target.build_configurations.each do |config|
  host_config = runner.build_configurations.find { |c| c.name == config.name }
  config.base_configuration_reference = host_config.base_configuration_reference
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.hankki.baeminFlutter.WalkingActivity',
    'PRODUCT_NAME' => 'WalkingActivity', 'PRODUCT_MODULE_NAME' => 'WalkingActivity',
    'DEVELOPMENT_TEAM' => host_config.build_settings['DEVELOPMENT_TEAM'],
    'CODE_SIGN_STYLE' => 'Automatic', 'INFOPLIST_FILE' => 'WalkingActivity/Info.plist',
    'GENERATE_INFOPLIST_FILE' => 'NO', 'SWIFT_VERSION' => '5.0',
    'IPHONEOS_DEPLOYMENT_TARGET' => '16.2', 'TARGETED_DEVICE_FAMILY' => '1,2',
    'SKIP_INSTALL' => 'YES', 'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)', 'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)',
    'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  })
end
target.frameworks_build_phase.files.each(&:remove_from_project)
runner.add_dependency(target) unless runner.dependencies.any? { |d| d.target == target }
embed = runner.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' } || runner.new_copy_files_build_phase('Embed App Extensions')
embed.dst_subfolder_spec = '13'
file = embed.add_file_reference(target.product_reference, true)
file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
runner.build_phases.delete(embed)
index = runner.build_phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' } || runner.build_phases.length
runner.build_phases.insert(index, embed)
project.save
