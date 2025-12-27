module DeployAssist
  module InstructionGenerators
    class ChromeExtensionGenerator
      def initialize(service_configuration)
        @config = service_configuration
        @setup = service_configuration.deployment_setup
        @data = service_configuration.collected_data
      end

      def generate
        [
          create_developer_account_instruction,
          prepare_extension_package_instruction,
          create_store_listing_instruction,
          upload_and_submit_instruction,
          handle_review_feedback_instruction
        ]
      end

      private

      def create_developer_account_instruction
        Instruction.create!(
          service_configuration: @config,
          step_number: 1,
          title: "Create Developer Account",
          instruction_type: 'external_link',
          instruction_text: <<~MD,
            ## Register for Chrome Web Store Developer Account

            ### Step 1: Create Account

            1. Go to [Chrome Web Store Developer Dashboard](https://chrome.google.com/webstore/devconsole)
            2. Sign in with your Google account
            3. Accept the Developer Agreement
            4. **Pay the one-time registration fee: $5 USD**
               - Required to publish extensions
               - One-time fee, valid forever
               - Use credit/debit card or Google Pay

            ### Step 2: Complete Your Profile

            Fill in the following information:
            - **Publisher Name**: #{@data['extension_name']&.split.first || 'Your Company'}
            - **Email**: #{@data['support_email']}
            - **Website**: #{@data['homepage_url']}

            **Verification:**
            - Email verification link will be sent
            - Click the link to verify your email
            - Account will be activated within a few minutes

            ### Important Notes:

            - The $5 fee is non-refundable
            - Your publisher name will be public on all your extensions
            - Choose a professional name that represents your brand
            - You can publish unlimited extensions with one account
          MD
          data: { url: 'https://chrome.google.com/webstore/devconsole' }
        )
      end

      def prepare_extension_package_instruction
        manifest_example = generate_manifest_json

        Instruction.create!(
          service_configuration: @config,
          step_number: 2,
          title: "Prepare Extension Package",
          instruction_type: 'copy_snippet',
          instruction_text: <<~MD,
            ## Package Your Chrome Extension

            ### 1. Create manifest.json (Manifest V3)

            Create a `manifest.json` file in your extension's root directory:

            ```json
            #{manifest_example}
            ```

            **Key Fields:**
            - **name**: "#{@data['extension_name']}"
            - **description**: "#{@data['short_description']}"
            - **permissions**: #{(@data['permissions'] || []).to_json}

            ### 2. Required Files

            Your extension package must include:

            ```
            my-extension/
            ├── manifest.json          (required)
            ├── icon-16.png           (16x16)
            ├── icon-48.png           (48x48)
            ├── icon-128.png          (128x128)
            ├── popup.html            (if using popup)
            ├── background.js         (if using service worker)
            ├── content.js            (if using content scripts)
            └── styles.css
            ```

            ### 3. Create .zip Package

            **On macOS/Linux:**
            ```bash
            cd my-extension
            zip -r ../my-extension.zip .
            ```

            **On Windows:**
            - Right-click the extension folder
            - Select "Send to" → "Compressed (zipped) folder"

            **Important:**
            - Zip the contents, not the folder itself
            - Maximum package size: 100 MB (compressed)
            - Do not include hidden files like .DS_Store or .git

            ### 4. Test Your Extension Locally

            Before uploading:

            1. Open Chrome → `chrome://extensions`
            2. Enable "Developer mode" (top-right toggle)
            3. Click "Load unpacked"
            4. Select your extension directory
            5. Test all features thoroughly

            **Test Checklist:**
            - ✅ All permissions work correctly
            - ✅ No console errors
            - ✅ Icons display properly
            - ✅ All features function as expected
          MD
          data: { snippet: manifest_example, filename: 'manifest.json' }
        )
      end

      def create_store_listing_instruction
        Instruction.create!(
          service_configuration: @config,
          step_number: 3,
          title: "Create Store Listing",
          instruction_type: 'manual_action',
          instruction_text: <<~MD,
            ## Fill Out Chrome Web Store Listing

            ### 1. Product Details

            Go to your [Developer Dashboard](https://chrome.google.com/webstore/devconsole) and click "New Item".

            **Basic Information:**
            - **Name**: #{@data['extension_name']}
            - **Summary**: #{@data['short_description']}
            - **Description**:
            ```
            #{@data['detailed_description']}
            ```
            - **Category**: #{@data['category']&.titleize}
            - **Language**: #{@data['primary_language']&.upcase}

            ### 2. Upload Store Assets

            **Icon (Required):**
            - Upload 128x128 PNG icon
            - File: #{@data['small_icon_url'] || 'Prepare your icon file'}

            **Screenshots (At least 1 required):**
            Upload screenshots (1280x800 or 640x400):
            #{format_screenshot_list}

            **Promotional Images (Optional but recommended):**
            - Large promo tile: 440x280
            - Small promo tile: 440x280
            - Marquee promo tile: 1400x560 (for featured listings)

            #{@data['demo_video_url'].present? ? "**Video:** #{@data['demo_video_url']}" : ''}

            ### 3. Privacy & Compliance

            **Privacy Policy:**
            - URL: #{@data['privacy_policy_url']}
            - Must be publicly accessible
            - Must explain data collection/usage

            **Single Purpose:**
            ```
            #{@data['single_purpose_description']}
            ```

            **Permissions Justification:**
            ```
            #{@data['permissions_justification']}
            ```

            ### 4. Distribution Settings

            **Visibility:**
            - ✅ Public (recommended)
            - ⬜ Unlisted (only accessible via direct link)
            - ⬜ Private (only for specific Google Workspace domains)

            **Pricing:**
            - ✅ Free (most common)
            - ⬜ Paid (requires payment setup)

            **Regions:**
            - Select "All regions" or choose specific countries

            ### 5. Save Draft

            Click "Save Draft" - don't submit yet! Review everything in the next step.
          MD
          data: {}
        )
      end

      def upload_and_submit_instruction
        Instruction.create!(
          service_configuration: @config,
          step_number: 4,
          title: "Upload & Submit for Review",
          instruction_type: 'manual_action',
          instruction_text: <<~MD,
            ## Submit Your Extension for Review

            ### 1. Upload Extension Package

            1. Go to your [Developer Dashboard](https://chrome.google.com/webstore/devconsole)
            2. Click on your extension item (or "New Item" if first time)
            3. Click "Package" tab
            4. Click "Upload new package"
            5. Select your `my-extension.zip` file
            6. Wait for upload to complete

            **Upload Requirements:**
            - Package must be less than 100 MB
            - Must contain valid manifest.json
            - All files must be properly structured

            ### 2. Pre-Submission Checklist

            Before clicking "Submit for Review", verify:

            ✅ **Functionality**
            - Extension works in multiple scenarios
            - No JavaScript errors in console
            - All features tested thoroughly

            ✅ **Privacy & Permissions**
            - Privacy policy is published at: #{@data['privacy_policy_url']}
            - All permissions are justified
            - Single purpose is clearly stated

            ✅ **Store Listing**
            - All required fields filled
            - Screenshots show actual features
            - Description is accurate and clear
            - Contact email is monitored: #{@data['support_email']}

            ✅ **Compliance**
            - No deceptive functionality
            - No malicious code
            - Follows [Chrome Web Store Policies](https://developer.chrome.com/docs/webstore/program-policies/)
            - Respects user privacy

            ### 3. Submit for Review

            1. Review all information one final time
            2. Click **"Submit for Review"**
            3. Confirm submission

            **What Happens Next:**
            - Extension enters review queue
            - Review typically takes 1-3 business days
            - Extensions with sensitive permissions may take 3-7 days
            - You'll receive email updates about review status

            ### 4. Review Status

            Check review status:
            1. Go to [Developer Dashboard](https://chrome.google.com/webstore/devconsole)
            2. Your extension will show one of these statuses:
               - 🟡 **Pending Review** - Waiting for review
               - 🟢 **Published** - Live on Chrome Web Store!
               - 🔴 **Rejected** - Needs changes (see next step)

            **Published Extensions:**
            - Usually appear in search within 1 hour
            - Accessible via direct link immediately
            - May take 24-48 hours for full indexing
          MD
          data: {}
        )
      end

      def handle_review_feedback_instruction
        Instruction.create!(
          service_configuration: @config,
          step_number: 5,
          title: "Handle Review Feedback",
          instruction_type: 'manual_action',
          instruction_text: <<~MD,
            ## Dealing with Review Feedback

            ### If Your Extension is Rejected

            **Common Rejection Reasons:**

            1. **Excessive Permissions**
               - Solution: Remove unnecessary permissions
               - Justify each permission clearly
               - Use minimum required permissions

            2. **Privacy Policy Issues**
               - Solution: Ensure policy is accessible
               - Clearly state what data is collected
               - Explain how data is used/stored

            3. **Single Purpose Violation**
               - Solution: Focus extension on one clear purpose
               - Remove unrelated features
               - Clarify purpose statement

            4. **Misleading Functionality**
               - Solution: Update description to match actual features
               - Remove exaggerated claims
               - Ensure screenshots show real features

            5. **Manifest V2 Usage**
               - Solution: Migrate to Manifest V3
               - Update service workers
               - Use modern APIs

            ### How to Respond to Rejection

            1. **Read the rejection email carefully**
               - Chrome Web Store team provides specific reasons
               - Note all policy violations mentioned

            2. **Make required changes**
               - Address each issue mentioned
               - Update code, manifest, or store listing
               - Create new .zip package if code changed

            3. **Resubmit**
               - Go to Developer Dashboard
               - Upload updated package (if needed)
               - Update store listing (if needed)
               - Add a note in "Message to Reviewers" explaining changes
               - Click "Resubmit for Review"

            ### Tips for Faster Approval

            ✅ **Be Transparent**
            - Clearly explain what your extension does
            - Don't hide functionality
            - Be honest about data collection

            ✅ **Minimal Permissions**
            - Only request what you absolutely need
            - Justify each permission in detail
            - Consider using optional permissions

            ✅ **Quality Screenshots**
            - Show actual extension features
            - No marketing fluff
            - Clear, professional images

            ✅ **Responsive Support**
            - Monitor #{@data['support_email']}
            - Respond to reviewer questions quickly
            - Be professional and courteous

            ### After Approval

            **Your Extension is Live! 🎉**

            - URL: `https://chrome.google.com/webstore/detail/[your-extension-id]`
            - Share the link with users
            - Add "Available in Chrome Web Store" badge to your website
            - Monitor ratings and reviews

            **Updating Your Extension:**
            1. Make changes to your code
            2. Update version in manifest.json
            3. Create new .zip package
            4. Upload to Developer Dashboard
            5. Submit for review (updates also get reviewed)

            **Analytics:**
            - View installs, ratings, and reviews in Developer Dashboard
            - Track user feedback
            - Monitor crash reports

            ### Support Resources

            - [Chrome Web Store Policies](https://developer.chrome.com/docs/webstore/program-policies/)
            - [Extension Development Guide](https://developer.chrome.com/docs/extensions/)
            - [Manifest V3 Migration Guide](https://developer.chrome.com/docs/extensions/mv3/intro/)
            - [Developer Support Forum](https://groups.google.com/a/chromium.org/g/chromium-extensions)
          MD
          data: {}
        )
      end

      def generate_manifest_json
        permissions = @data['permissions'] || ['storage']

        {
          manifest_version: 3,
          name: @data['extension_name'] || 'My Extension',
          version: '1.0.0',
          description: @data['short_description'] || 'Extension description',
          permissions: permissions,
          icons: {
            '16': 'icon-16.png',
            '48': 'icon-48.png',
            '128': 'icon-128.png'
          },
          action: {
            default_popup: 'popup.html',
            default_icon: {
              '16': 'icon-16.png',
              '48': 'icon-48.png'
            }
          }
        }.to_json(indent: '  ')
      end

      def format_screenshot_list
        screenshots = (@data['screenshot_urls'] || '').split("\n").reject(&:blank?)
        if screenshots.any?
          screenshots.map.with_index(1) { |url, i| "#{i}. #{url.strip}" }.join("\n")
        else
          "- Prepare 1-5 screenshots showing your extension's features"
        end
      end
    end
  end
end
