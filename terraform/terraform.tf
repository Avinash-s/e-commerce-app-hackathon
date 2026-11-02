terraform {
  backend "s3" {
    bucket = "avi-s3-backend-tws-hackathon"
    key    = "backend-locking"
    region = "us-east-1"
    use_lockfile = true
  }
}