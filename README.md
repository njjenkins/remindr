# remindR <img src='pictures/logo.png' align="right" height="100" /></a>

## Overview
	
remindR is a system for automating academic project reminders using R on Mac, Linux and Windows. Users can define what kind of reminders they want to obtain, which Gmail address to send the reminders from, and which addresses the reminders will be sent to. This system can help project managers, researchers, research assistants and students keep track of deadlines related to academic projects, reducing the burden of tracking these events manually and the eliminating the possibility of making manual mistakes. remindR uses packages [cronR](https://github.com/bnosac/cronR) (Mac OS X and Linux) and [taskscheduleR](https://github.com/bnosac/taskscheduleR) (Windows) to schedule recurring tasks.

This system can send out four types of reminders:

1. **Future conference reminders**. These are reminders to check if future conferences have announced details that would allow to track them (deadlines, submission links, and descriptions).
2. **Conference deadlines**. Reminders to submit papers or abstracts to conferences.
3. **Upcoming presentations**. Reminders for upcoming presentations, including slide submission deadlines.
4. **Grant deadlines**. This can be useful both when applying for grants and when submitting grant deliverables.

The original version for Mac OS X was developed by [César Landín](github.com/clandinq), and the Windows version developed joint with [Vicente Corral](github.com/vicentecorral).

## Set up
There are three steps for setting up the remindR system:
1. Clone the repo to your project folder
2. Fill out conference, grant and presentation information
3. Set up Gmail API and OAuth consent screen
4. Define reminder parameters

### 1. Clone the repo
First clone the repo locally into the desired project folder. This system works best with the folder structure defined by [Sean Higgins](https://seankhiggins.com/) in his [R guide](https://github.com/skhiggins/r_guide). The recommendation is to add the system to the Dropbox folder so that all project members (including those not using GitHub) can see programmed events in the reminder datasets. For example, below is a brief example of the terminal commands to clone a project titled "Health RCT".

```r
cd Work/health_rct
git clone https://github.com/clandinq/remindr reminders
cd reminders
rm -r pictures/
```
This will download 2 scripts, 5 .xlsx files, this readme and a .Rproj file. 

### 2. Fill out Excel files with conference, grant and presentation information
You need to modify two sets of files to set up the reminder system. First, one to four .xlsx files containing details about conferences, grants and presentations, that will be used to send the reminders. All files are included in the folder `data`. The files and variables are:

1. `rem_future_conferences.xlsx`: **Future conference reminders**
    1. `deadline`: Estimated *date* the conference will take place in yyyy_mm_dd text format. This format is used to prevent Excel from automatically changing the date format.
    2. `description`: Description of the conference.
    3. `website`: Conference website.
    4. `complete`: This variable defines whether reminders need to be sent or not. If all scheduled reminders have been sent, it is marked as complete (`complete = 1`). The default value is `complete = 0`. Set `complete = 1` in the Excel document if it is not necessary to send this set of reminders anymore (for example, when completing a submission before the final reminder).
2. `rem_conference_deadlines.xlsx`: **Conference deadlines**
    1. `deadline`: Conference abstract or paper submission deadline in yyyy_mm_dd text format (the date in the deadline's own time zone). **If `deadline_time` is blank and the deadline is before midnight local time (where the reminders are running), set the deadline as one day before.** When `deadline_time` is filled in, this is automatic: reminders are scheduled from the due time converted to `reminder_cutoff_tz`, and sent one day earlier if it is due before `reminder_cutoff_time` there (5:00 PM Eastern by default).
    2. `deadline_time`: Time the submission is due, in the deadline's own time zone (e.g. *23:59*, *11:59 PM*, *5pm*). Can be left blank. When filled in, reminder emails show the deadline time and the same time converted to the time zones set in `display_timezones` (see [step 4](#4-define-reminder-parameters)).
    3. `timezone`: Time zone of `deadline_time`. Accepts IANA names (*Europe/Berlin*, *America/Los_Angeles*), common abbreviations (*EST*, *PT*, *CET*, *AoE*) or UTC offsets (*UTC+2*, *GMT-05:00*). Abbreviations follow daylight saving time, so *EST* entered for a July deadline is read as Eastern time (EDT); use an offset such as *UTC-5* for a fixed offset. If left blank, the time is assumed to be in the computer's local time zone.
    4. `notification`: Date notification on admission sent in yyyy_mm_dd text format. Can be left blank.
    5. `description`: Description of the conference.
    6. `questions`: Line indicating who to ask conference questions. Can be left blank.
    7. `submission`: Link to submit abstract or paper to.
    8. `dead_type`: *abstract* or *paper*.
    9. `website`: Conference website.
    10. `complete`: This variable defines whether reminders need to be sent or not. If all scheduled reminders have been sent, it is marked as complete (`complete = 1`). The default value is `complete = 0`. Set `complete = 1` in the Excel document if it is not necessary to send this set of reminders anymore (for example, when completing a submission before the final reminder).
3. `rem_upcoming_presentations.xlsx`: **Reminders for upcoming presentations**, including slide submission deadlines
    1. `deadline`: Upcoming presentation date or slide submission deadline in yyyy_mm_dd text format.
    2. `dead_type`: *conference presentation*, *slide submission* or *paper submission*. Matched by keyword: anything containing "slide" sends a slide submission reminder, anything containing "paper" a paper submission reminder, and anything else a general presentation reminder.
    3. `description`: Description of the conference.
    4. `submission`: Link to submit slides to. Can be left blank if `dead_type`="conference presentation".
    5. `website`: Conference website.
    6. `complete`: This variable defines whether reminders need to be sent or not. If all scheduled reminders have been sent, it is marked as complete (`complete = 1`). The default value is `complete = 0`. Set `complete = 1` in the Excel document if it is not necessary to send this set of reminders anymore (for example, when completing a submission before the final reminder).
4. `rem_grant_deadlines.xlsx`: **Grant deadlines**
    1. `deadline`: Grant deadline in yyyy_mm_dd text format.
    2. `description`: Description of the grant. **Specify the deadline’s time and date in the description.** For example: *Financial Economics grant (due on 2022-12-03 18:00 CST).*
    3. `dead_type`: *deliverable*, *proposal* or other (cannot be blank).
    4. `details`: Details about what the submission requires.
    5. `questions`: Line indicating who to ask conference questions. Can be left blank.
    6. `submission`: Link to submit grant deliverable/proposal/etc.
    7.  `complete`: This variable defines whether reminders need to be sent or not. If all scheduled reminders have been sent, it is marked as complete (`complete = 1`). The default value is `complete = 0`. Set `complete = 1` in the Excel document if it is not necessary to send this set of reminders anymore (for example, when completing a submission before the final reminder).

The four Excel files downloaded contain data examples, which must be overwritten before proceeding with the setup. You only need to modify the files for which you will send reminders. For example, if you will not be sending any grant deadline reminders, you can leave the template blank and simply select in the next step that you will not be sending these reminders out.

### 3. Set up Gmail API and OAuth consent screen
1. **Set up project and enable the Gmail API**
    1. Open and log into the [Google Cloud Console](https://console.cloud.google.com/).
    2. [Create a Google Cloud project](https://developers.google.com/workspace/guides/create-project) and name the project "remindR".

		<img src="https://github.com/clandinq/remindr/blob/main/pictures/gproj_1.png" align="center" height="40%" width="40%">
	
    3. Select your project on the top left dropdown menu.

		<img src="https://github.com/clandinq/remindr/blob/main/pictures/gproj_2.png" align="center" height="20%" width="20%">
	
    4. Click on **APIs & Services** > **Enabled APIs services**.

		<img src="https://github.com/clandinq/remindr/blob/main/pictures/gproj_3.png" align="center" height="30%" width="30%">
	
    5. Click on **+ Enable APIs and Services**.

		<img src="https://github.com/clandinq/remindr/blob/main/pictures/gproj_4.png" align="center" height="30%" width="30%">
	
    6. Look up and select **Gmail API**.

		<img src="https://github.com/clandinq/remindr/blob/main/pictures/gproj_5.png" align="center" height="40%" width="40%">
	
    7. Enable the Gmail API.

		<img src="https://github.com/clandinq/remindr/blob/main/pictures/gproj_6.png" align="center" height="20%" width="20%">
    
2. **Configure OAuth consent screen and obtain credentials**
    1. On the top-left menu, click **Menu** > **APIs & Services** > **Credentials** > **+ Create Credentials**.

		<img src="https://github.com/clandinq/remindr/blob/main/pictures/gauth_1.png" align="center" height="30%" width="30%">
	
    2. Configure your consent screen
	    1. Select user type **External**.

			<img src="https://github.com/clandinq/remindr/blob/main/pictures/gauth_2.png" align="center" height="30%" width="30%">
		
	    2. Name the app "remindR" and select your email as the support email address.

			<img src="https://github.com/clandinq/remindr/blob/main/pictures/gauth_3.png" align="center" height="30%" width="30%">
		
	    3. Continue until the Summary step and click on **Back to Dashboard**. 

	    4. Click on **Publish App**.
	    
			<img src="https://github.com/clandinq/remindr/blob/main/pictures/gauth_5.png" align="center" height="30%" width="30%">

    4. Select again **Menu** > **APIs & Services** > **Credentials** > **+ Create Credentials** and select **OAuth client ID**.
    5. Select Desktop App and name the app as remindR.

		<img src="https://github.com/clandinq/remindr/blob/main/pictures/gauth_4.png" align="center" height="30%" width="30%">
	
    6. Download client secret JSON file and store in a local folder (write down the name of the file and the location).

3. **Allow access to your account from R**
    1. Run until line 32 of script 2_create_send_reminders.R. A window will open asking for your Gmail login information. Select your Google account.
    
		<img src="https://github.com/clandinq/remindr/blob/main/pictures/gr_1.png" align="center" height="30%" width="30%">

    2. Allow access to your account.
    
		<img src="https://github.com/clandinq/remindr/blob/main/pictures/gr_2.png" align="center" height="20%" width="20%">
    
    3. You will receive a confirmation message on R once authentication is complete.

		<img src="https://github.com/clandinq/remindr/blob/main/pictures/gr_3.png" align="center" height="20%" width="20%">
 
### 4. Define reminder parameters
Second, general project and specific reminder parameters need to be set in script `1_define_reminder_parameters.R`, which saves these parameters in `rem_parameters.xlsx` and sets up a repeating task with cronR. This script can be found in the folder `scripts`. **If using Windows, you must open R with administrator privileges (right click on the R icon) in order for the script to run properly**.

1. **General project parameters**. These apply for all reminders in a project.
   
   - `proj_name`: define a short project name to be used in email headers.
   - `email_from`: a Gmail address to send emails from.
   - `name_from`: name to use for email signature.
   - `secret_path`: absolute path to Gmail client secret generated in [previous section](https://github.com/clandinq/remindr/blob/main/README.md#3-set-up-gmail-api-and-oauth-consent-screen).

2. **Specific reminder parameters**. These are individual to each reminder.

   - `_activate`: boolean to define whether reminder will be active.
   - `_emails`: comma separated emails to send reminders to (e.g. "john.smith@gmail.com, jane.smith@hotmail.com").
   - `_freq`: comma separated number of days before deadline to send reminders (e.g. "1, 2, 5, 10").
   - `display_timezones` (conference deadlines only): comma separated time zones to show deadline times in (e.g. "America/New_York, America/Chicago"). Use IANA names so daylight saving time is handled automatically (EST/EDT, CST/CDT). If left blank (""), the computer's time zone is used.
   - `reminder_cutoff_time` and `reminder_cutoff_tz` (conference deadlines with a `deadline_time` only): deadlines due before this time in this zone get all their reminders one day earlier, so the final reminder isn't sent the morning of an early deadline. Defaults: "17:00" and "America/New_York". For these deadlines, email subjects count the real days left until the due date (e.g. "FINAL REMINDER - PAPER SUBMISSION DEADLINE TOMORROW: 2026-12-02 9:00 AM EST").

Once the data for the reminders has been filled out in the Excel files, and the parameters set in the first script, you can run `1_define_reminder_parameters.R` to conclude the setup of the reminder system. 

## Regular usage
Once the initial set up has been completed, you can add conferences, grants and presentations by modifying the relevant Excel files.

To delete reminders:
- **Mac OS X and Linux**. Run the following commands in R:
    ```R
    pacman::p_load(cronR)
    cron_ls() # This lists out all the scheduled tasks
    cron_rm("name of task") # Insert the name of the reminder task you want to remove
    ``` 
- **Windows**. Run the following commands in R:
    ```R
    pacman::p_load(taskscheduleR)
    taskscheduler_ls() # This lists out all the scheduled tasks
    taskscheduler_delete("name of task") # Insert the name of the reminder task you want to remove
    ``` 
On Windows, it is necessary to delete a reminder before scheduling another reminder with the same name.

