import jenkins.model.*
import hudson.model.*
import hudson.slaves.* 
import hudson.plugins.sshslaves.*
  
Jenkins.instance.addNode(
  new DumbSlave(
	"test-slave",
	"test slave description",
	"/home/jenkins",
	"1",
	Node.Mode.NORMAL,
	null,
	new SSHLauncher(
	  "slave",
	  22,
	  "jenkins",
	  "",
	  "/var/jenkins_home/.ssh/id_rsa",
	  "",
	  "",
	  "",
	  ""
	),
	new RetentionStrategy.Always(),
	[]
  )
)