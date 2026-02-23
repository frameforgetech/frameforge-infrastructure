output "videos_bucket_id" {
  description = "Videos bucket ID"
  value       = aws_s3_bucket.videos.id
}

output "videos_bucket_arn" {
  description = "Videos bucket ARN"
  value       = aws_s3_bucket.videos.arn
}

output "results_bucket_id" {
  description = "Results bucket ID"
  value       = aws_s3_bucket.results.id
}

output "results_bucket_arn" {
  description = "Results bucket ARN"
  value       = aws_s3_bucket.results.arn
}
