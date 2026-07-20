CREATE TABLE `users` (
	`id` text PRIMARY KEY NOT NULL,
	`created_at` integer NOT NULL,
	`deleted_at` integer
);
--> statement-breakpoint
CREATE TABLE `account_identities` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`provider` text NOT NULL,
	`provider_subject` text NOT NULL,
	`created_at` integer NOT NULL,
	`deleted_at` integer,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE restrict
);
--> statement-breakpoint
CREATE UNIQUE INDEX `account_identities_provider_subject_unique` ON `account_identities` (`provider`,`provider_subject`);
--> statement-breakpoint
CREATE TABLE `account_sessions` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`token_hash` text NOT NULL,
	`expires_at` integer NOT NULL,
	`created_at` integer NOT NULL,
	`revoked_at` integer,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `account_sessions_token_hash_unique` ON `account_sessions` (`token_hash`);
--> statement-breakpoint
CREATE INDEX `account_sessions_user_expires_idx` ON `account_sessions` (`user_id`,`expires_at`);
--> statement-breakpoint
ALTER TABLE `wishes` ADD `user_id` text;
--> statement-breakpoint
CREATE INDEX `wishes_user_created_idx` ON `wishes` (`user_id`,`created_at`);
--> statement-breakpoint
ALTER TABLE `wish_responses` ADD `user_id` text;
--> statement-breakpoint
CREATE INDEX `wish_responses_user_created_idx` ON `wish_responses` (`user_id`,`created_at`);
