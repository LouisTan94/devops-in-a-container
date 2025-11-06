Prerequisite:
1. DNS name set up for GitLab.
2. GitLab is fully deployed and the admin portal is accessible before proceeding.

Tutorial:
1. Since you're using an **Application Load Balancer (ALB)** to route traffic to GitLab inside your EC2 instance, you need to configure GitLab to use the ALB DNS (`uat.aocs.changiairport.com`) instead of `cpos-gitlab`.

---

### **1. Update GitLab Configuration (`gitlab.rb`)**
Inside your GitLab container, edit the configuration:

```sh
docker exec -it gitlab bash
nano /etc/gitlab/gitlab.rb
```

Find and update the `external_url` to match your ALB DNS:

```ruby
external_url 'http://uat.aocs.changiairport.com'
```

If your ALB uses HTTPS, set it to:

```ruby
external_url 'https://uat.aocs.changiairport.com'
```

---

### **2. Configure Nginx in GitLab**
By default, GitLab’s internal Nginx may interfere with the ALB routing. To avoid issues, ensure these settings are enabled in `gitlab.rb`:

```ruby
nginx['listen_port'] = 80 
nginx['listen_https'] = false  # Set to true if ALB handles SSL termination
nginx['real_ip_trusted_addresses'] = ['<ALB Private IP>']
nginx['real_ip_header'] = 'X-Forwarded-For'
nginx['real_ip_recursive'] = 'on'
```
If ALB is handling SSL, also enable:
```ruby
nginx['redirect_http_to_https'] = true
```

---

### **3. Reconfigure and Restart GitLab**
Apply the changes:
```sh
gitlab-ctl reconfigure
gitlab-ctl restart
```

---

### **4. Ensure ALB Health Checks and Security Group Rules**
- Your **ALB Listener** is on **port 8080**, routing to the EC2 **port 80**.
- Ensure GitLab is listening on **port 80** inside EC2.
- Update **ALB health checks** to target `/-/health` on port **80**.

---

Now, GitLab should be accessible at `http://uat.aocs.changiairport.com`.