# test_gitlab_api.py
import os
import time
import requests
from datetime import datetime
from dotenv import load_dotenv

class GitLabAPITester:
    def __init__(self):
        # Load environment variables
        load_dotenv()
        
        # Initialize configuration
        self.base_url = os.getenv('GITLAB_API_URL', 'https://gitlab.com/api/v4')
        self.project_id = os.getenv('GITLAB_PROJECT_ID')
        self.trigger_token = os.getenv('GITLAB_TRIGGER_TOKEN')
        
        # Validate required environment variables
        if not all([self.project_id, self.trigger_token]):
            raise ValueError("Missing required environment variables. Please check .env file.")
        
        # Setup session for requests
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
        })
        
        # Store test pipeline ID
        self.test_pipeline_id = None

    def run_all_tests(self):
        """Run all GitLab API tests"""
        print("Starting GitLab API Tests...\n")
        tests = [
            self.test_api_connection,
            self.test_project_access,
            self.test_pipeline_trigger,
            self.test_pipeline_status
        ]
        
        success_count = 0
        for test in tests:
            try:
                test()
                success_count += 1
            except Exception as e:
                print(f"❌ {test.__name__} failed: {str(e)}")
                if hasattr(e, 'response'):
                    print(f"Response status: {e.response.status_code}")
                    print(f"Response body: {e.response.text}")
        
        print(f"\nTest Summary: {success_count}/{len(tests)} tests passed")

    def test_api_connection(self):
        """Test basic connection to GitLab API"""
        print("1️⃣ Testing API Connection...")
        try:
            response = self.session.get(f"{self.base_url}/version")
            response.raise_for_status()
            print(f"✅ API Connection successful! GitLab version: {response.json()['version']}")
        except requests.exceptions.RequestException as e:
            raise Exception(f"API Connection failed: {str(e)}")

    def test_project_access(self):
        """Test access to the specified project"""
        print("\n2️⃣ Testing Project Access...")
        try:
            response = self.session.get(f"{self.base_url}/projects/{self.project_id}")
            response.raise_for_status()
            project_data = response.json()
            print("✅ Project Access successful!")
            print(f"Project name: {project_data['name']}")
            print(f"Visibility: {project_data['visibility']}")
        except requests.exceptions.RequestException as e:
            raise Exception(f"Project Access failed: {str(e)}")

    def test_pipeline_trigger(self):
        """Test triggering a pipeline"""
        print("\n3️⃣ Testing Pipeline Trigger...")
        try:
            # Prepare test data
            test_data = {
                "token": self.trigger_token,
                "ref": "main",
                "variables": {
                    "TEST_VARIABLE": "test_value",
                    "TIMESTAMP": datetime.now().isoformat()
                }
            }
            
            response = self.session.post(
                f"{self.base_url}/projects/{self.project_id}/trigger/pipeline",
                json=test_data
            )
            response.raise_for_status()
            
            pipeline_data = response.json()
            self.test_pipeline_id = pipeline_data['id']
            
            print("✅ Pipeline Trigger successful!")
            print(f"Pipeline ID: {pipeline_data['id']}")
            print(f"Status: {pipeline_data['status']}")
        except requests.exceptions.RequestException as e:
            raise Exception(f"Pipeline Trigger failed: {str(e)}")

    def test_pipeline_status(self):
        """Test retrieving pipeline status"""
        if not self.test_pipeline_id:
            print("\n4️⃣ Skipping Pipeline Status test (no pipeline ID available)")
            return

        print("\n4️⃣ Testing Pipeline Status Retrieval...")
        try:
            # Wait briefly for pipeline to initialize
            time.sleep(2)
            
            response = self.session.get(
                f"{self.base_url}/projects/{self.project_id}/pipelines/{self.test_pipeline_id}"
            )
            response.raise_for_status()
            
            pipeline_data = response.json()
            print("✅ Pipeline Status Retrieval successful!")
            print(f"Current Status: {pipeline_data['status']}")
            print(f"Created: {pipeline_data['created_at']}")
            
            # Optional: Monitor pipeline status for a while
            self.monitor_pipeline_status()
        except requests.exceptions.RequestException as e:
            raise Exception(f"Pipeline Status Retrieval failed: {str(e)}")

    def monitor_pipeline_status(self, timeout=60, interval=5):
        """Monitor pipeline status for a specified duration"""
        print("\nMonitoring pipeline status...")
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            try:
                response = self.session.get(
                    f"{self.base_url}/projects/{self.project_id}/pipelines/{self.test_pipeline_id}"
                )
                response.raise_for_status()
                status = response.json()['status']
                
                print(f"Status at {datetime.now().strftime('%H:%M:%S')}: {status}")
                
                if status not in ['pending', 'running']:
                    print(f"Pipeline finished with status: {status}")
                    break
                
                time.sleep(interval)
            except requests.exceptions.RequestException as e:
                print(f"Error monitoring pipeline: {str(e)}")
                break

if __name__ == "__main__":
    tester = GitLabAPITester()
    tester.run_all_tests()